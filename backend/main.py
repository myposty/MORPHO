import asyncio
import base64
import io
import threading
import time

import torch
from diffusers import AutoPipelineForText2Image, LCMScheduler
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from rich.align import Align
from rich.console import Console
from rich.rule import Rule
from rich.text import Text

app = FastAPI()
# El front (:8080) consulta /status en (:8000) -> hace falta CORS.
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)

MODEL = "Lykon/dreamshaper-8-lcm"  # SD1.5 + LCM: chico, rapido, sin filtro
STEPS = 7        # LCM: 4-8 pasos
GUIDANCE = 2.0   # LCM usa guidance bajo (~1-2)

pipe = None
gpu_lock = asyncio.Lock()
# Estado de carga, que el front consulta por /status.
state = {"ready": False, "stage": "iniciando", "elapsed": 0, "progress": 0}


@app.get("/status")
def status():
    return state


def _print_banner():
    art = r"""
 __  __  ___  ____  ____  _   _  ___
|  \/  |/ _ \|  _ \|  _ \| | | |/ _ \
| |\/| | | | | |_) | |_) | |_| | | | |
| |  | | |_| |  _ <|  __/|  _  | |_| |
|_|  |_|\___/|_| \_\_|   |_| |_|\___/
"""
    # Sin caja a proposito: los bordes de caja (─ │) se desalinean en visores
    # como Docker Desktop (renderizan esos chars mas anchos que el ASCII). Solo
    # contenido + reglas, que no se pueden romper. force_terminal: color en docker logs.
    c = Console(force_terminal=True, width=72)
    c.print(Align.center(Text(art, style="bold cyan")))
    c.print(Align.center(Text("🦋  generación de imágenes con IA en tiempo real", style="cyan")))
    c.print(Rule(style="grey37"))
    c.print(Text.assemble(
        ("  ✓ ", "bold green"), ("servidor listo", "white"),
        ("    ▸  ", "grey50"), ("http://localhost:8080", "underline bright_blue"),
    ))
    c.print()
    c.print(Text("  ⚠  aviso de responsabilidad", style="bold yellow"))
    c.print(Text(
        "  las imágenes son generadas por IA. el contenido creado es\n"
        "  responsabilidad exclusiva de quien lo genera y utiliza; este\n"
        "  servicio no se hace responsable del uso que se le dé.",
        style="grey58",
    ))
    c.print(Rule(style="grey37"))
    c.print()


def _load_model():
    """Carga el modelo en segundo plano para que uvicorn arranque ya y el front
    pueda mostrar progreso. La primera vez tambien lo descarga.

    El % se ancla a hitos reales (modelo cargado=85, warmup=99, listo=100) y entre
    hito e hito avanza por tiempo (+1%/s) para que la barra no se quede quieta."""
    global pipe
    t0 = time.time()
    ceil = {"v": 85}  # techo actual hasta el proximo hito

    def tick():
        while not state["ready"]:
            state["elapsed"] = int(time.time() - t0)
            if state["progress"] < ceil["v"] - 1:
                state["progress"] += 1
            time.sleep(1)

    threading.Thread(target=tick, daemon=True).start()

    state["stage"] = "cargando modelo (la primera vez tambien lo descarga)"
    p = AutoPipelineForText2Image.from_pretrained(MODEL, torch_dtype=torch.float16).to("cuda")
    p.scheduler = LCMScheduler.from_config(p.scheduler.config)
    # VAE en fp32: evita el NaN (imagen negra) del fp16. El unet sigue en fp16.
    p.vae = p.vae.to(torch.float32)
    state["progress"], ceil["v"] = 85, 99  # modelo cargado

    state["stage"] = "calentando"
    p(prompt="warmup", num_inference_steps=STEPS, guidance_scale=GUIDANCE,
      height=512, width=512, output_type="latent")  # compila kernels CUDA

    pipe = p
    state["progress"] = 100
    state["stage"] = "listo"
    state["ready"] = True
    _print_banner()


@app.on_event("startup")
def _startup():
    threading.Thread(target=_load_model, daemon=True).start()


def _is_black(img) -> bool:
    # NaN -> imagen toda negra (pixeles ~0). Un pixel max < 8 = negra.
    return max(ch[1] for ch in img.getextrema()) < 8


def _decode_fp32(latents):
    lat = latents.to(torch.float32) / pipe.vae.config.scaling_factor
    with torch.no_grad():
        image = pipe.vae.decode(lat, return_dict=False)[0]
    return pipe.image_processor.postprocess(image, output_type="pil")[0]


def generate(prompt: str) -> str:
    img = None
    for _ in range(3):  # red de seguridad contra imagen negra
        latents = pipe(
            prompt=prompt,
            num_inference_steps=STEPS,
            guidance_scale=GUIDANCE,
            height=512,
            width=512,
            output_type="latent",
        ).images
        img = _decode_fp32(latents)
        if not _is_black(img):
            break
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return base64.b64encode(buf.getvalue()).decode()


@app.websocket("/ws")
async def ws(sock: WebSocket):
    await sock.accept()
    latest = {"prompt": None, "seq": 0}
    done_seq = 0

    async def receiver():
        while True:
            latest["prompt"] = await sock.receive_text()
            latest["seq"] += 1

    recv_task = asyncio.create_task(receiver())
    try:
        while True:
            if not state["ready"]:
                await asyncio.sleep(0.1)
                continue
            # Solo genera el ultimo prompt; descarta los intermedios mientras escribe.
            if latest["seq"] != done_seq and latest["prompt"]:
                done_seq = latest["seq"]
                prompt = latest["prompt"]
                async with gpu_lock:
                    b64 = await asyncio.to_thread(generate, prompt)
                await sock.send_text(b64)
            else:
                await asyncio.sleep(0.02)
    except WebSocketDisconnect:
        pass
    finally:
        recv_task.cancel()
