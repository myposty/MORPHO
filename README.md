# MORPHO

Genera imágenes con IA **en tiempo real mientras escribís**. Todo en Docker.

Stack: DreamShaper-8-LCM (modelo) · FastAPI + WebSocket (backend) · Vue3 (frontend).

**Funciona en cualquier equipo.** El launcher detecta el hardware y arranca solo:

| Hardware | Modo | Velocidad |
|----------|------|-----------|
| **GPU NVIDIA** (driver ≥ 525.60.13) | CUDA | ⚡ tiempo real |
| **GPU AMD** (Linux + ROCm) | ROCm — *experimental* | ⚡ rápido |
| **Sin GPU / gráfica integrada** | CPU (fallback automático) | 🐢 lento (pero anda) |

La app **siempre levanta**; en el header te muestra qué está usando (GPU + modelo, o CPU).

---

## 1. Requisito

- **Docker** (en Windows: Docker Desktop con WSL2).
- Para usar GPU NVIDIA: driver **≥ 525.60.13** + soporte GPU en Docker. Verificá con:
  ```bash
  docker run --rm --gpus all nvidia/cuda:12.1.1-base-ubuntu22.04 nvidia-smi
  ```
- Sin GPU no hace falta nada: corre en CPU (lento).

## 2. Arrancar

Usá el launcher: detecta el hardware (NVIDIA / AMD / CPU) y levanta solo.

```bash
# Windows (PowerShell)
.\run.ps1

# Linux / Mac
chmod +x run.sh   # solo la primera vez, si no tiene permiso de ejecución
./run.sh
```

Abrí 👉 **http://localhost:8080**

> `docker compose up -d` directo también funciona (arranca en cualquier máquina), pero
> **sin GPU**: corre en CPU. El **launcher** es el que activa la GPU cuando la hay.

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

- **Dice "🐢 CPU" pero tenés GPU NVIDIA** → usá el launcher (`.\run.ps1` / `./run.sh`), no `docker compose up -d` pelado. Si igual no la toma, revisá el driver (≥ 525.60.13) y el soporte GPU de Docker (paso 1).
- **Se queda en la barra de carga** → está bajando/cargando el modelo, esperá (1ra vez tarda 1-2 min; en CPU más).
- **AMD**: es experimental y solo Linux con ROCm. Si no levanta, no está soportado tu equipo.
- **El modelo descargado** queda en `backend/models/` (no se sube a GitHub).

## Tocar cosas

Todo en `backend/main.py`:
- `STEPS` (1-8): más = mejor detalle, más lento.
- `GUIDANCE` (1-2): fidelidad al prompt.
