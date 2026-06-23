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

echo "MORPHO - detectando GPU NVIDIA..."

# Test liviano: --gpus all dispara el hook NVIDIA. Si no hay GPU, falla.
if docker run --rm --gpus all hello-world >/dev/null 2>&1; then
  echo "  GPU NVIDIA detectada -> levantando CON GPU"
  $DC -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
else
  echo "  Sin GPU NVIDIA accesible -> levanto igual (la app avisara en pantalla)"
  $DC up -d --build
fi

echo ""
echo "Abri -> http://localhost:8080"
echo "Logs  -> $DC logs -f backend"
