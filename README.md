# MORPHO

Genera imágenes con IA **en tiempo real mientras escribís**. Todo en Docker.

Stack: DreamShaper-8-LCM (modelo) · FastAPI + WebSocket (backend) · Vue3 (frontend).

> ⚠️ **Solo NVIDIA.** MORPHO requiere una **GPU NVIDIA con CUDA**. No funciona en CPU
> ni en GPUs AMD. Si no se detecta una GPU NVIDIA, el backend **no arranca** y el front
> muestra el error.

---

## 1. Requisito

- **GPU NVIDIA** con **driver ≥ 525.60.13** (lo que pide CUDA 12.1). Si el driver es más viejo, MORPHO lo detecta y te avisa que lo actualices.
- **Docker** con soporte GPU. En Windows: Docker Desktop con WSL2 (activado por defecto).

Probá que Docker ve tu GPU:

```bash
docker run --rm --gpus all nvidia/cuda:12.1.1-base-ubuntu22.04 nvidia-smi
```

Si lista tu placa, estás listo. **Sin GPU NVIDIA no funciona.**

## 2. Arrancar

```bash
docker compose build
docker compose up -d
```

Abrí 👉 **http://localhost:8080**

La primera vez baja el modelo (~5GB) solo. Vas a ver una barra de carga; cuando llega a 100% ya podés usarlo.

## 3. Usar

- **Escribí** un prompt → la imagen se genera sola.
- **Enter** → otra imagen con el mismo prompt.
- **Borrás el texto** → se borra la imagen.

---

## Comandos

```bash
docker compose logs -f backend   # ver qué está haciendo
docker compose down              # apagar
docker compose up -d             # prender (ya no baja nada)
```

## Si algo falla

- **`could not select device driver "nvidia"`** → falta soporte GPU en Docker (mirá el paso 1).
- **Se queda en la barra de carga** → está bajando/cargando el modelo, esperá (1ra vez tarda 1-2 min).
- **El modelo descargado** queda en `backend/models/` (no se sube a GitHub).

## Tocar cosas

Todo en `backend/main.py`:
- `STEPS` (1-8): más = mejor detalle, más lento.
- `GUIDANCE` (1-2): fidelidad al prompt.
