#!/usr/bin/env sh
# MORPHO - launcher Linux/Mac. Detecta GPU y version de Compose; levanta con o sin GPU.
echo ""

# Detecta Compose v2 ("docker compose") vs v1 ("docker-compose").
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Docker Compose no encontrado. Instala Docker."
  exit 1
fi

echo "MORPHO - detectando hardware..."

# 1) NVIDIA: --gpus all dispara el hook NVIDIA. Si no hay, falla.
if docker run --rm --gpus all hello-world >/dev/null 2>&1; then
  echo "  GPU NVIDIA detectada -> levantando con GPU"
  $DC -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
# 2) AMD ROCm (experimental, solo Linux): /dev/kfd indica GPU AMD.
elif [ -e /dev/kfd ]; then
  echo "  GPU AMD (ROCm, experimental) detectada -> levantando con GPU"
  $DC -f docker-compose.yml -f docker-compose.amd.yml up -d --build
# 3) Sin GPU: CPU (lento, pero funciona).
else
  echo "  Sin GPU -> levantando en CPU (la generacion sera lenta)"
  $DC up -d --build
fi

echo ""
echo "Abri -> http://localhost:8080"
echo "Logs  -> $DC logs -f backend"
