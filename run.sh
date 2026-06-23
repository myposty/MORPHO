#!/usr/bin/env sh
# MORPHO - launcher Linux/Mac. Detecta hardware + Compose y hace el build con una
# barra de progreso animada (sin dependencias). Logs ocultos por defecto.
#   ./run.sh        -> lindo (barra + %), logs escondidos
#   ./run.sh -v     -> muestra los logs completos del build (desplegar)

VERBOSE=0
[ "$1" = "-v" ] || [ "$1" = "--verbose" ] && VERBOSE=1

echo ""

# --- Detecta Compose v2 ("docker compose") vs v1 ("docker-compose") ---
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Docker Compose no encontrado. Instala Docker."
  exit 1
fi

# --- Barra de 24 chars segun porcentaje ---
_bar() {
  filled=$(( $1 * 24 / 100 ))
  b=''; n=0
  while [ "$n" -lt 24 ]; do
    if [ "$n" -lt "$filled" ]; then b="${b}#"; else b="${b}."; fi
    n=$(( n + 1 ))
  done
  printf '%s' "$b"
}

# --- Build del backend con barra animada. $@ = args de compose (-f ...). ---
build_pretty() {
  if [ "$VERBOSE" = "1" ]; then
    $DC "$@" build backend || exit 1
    return
  fi
  LOG=$(mktemp 2>/dev/null || echo /tmp/morpho_build.log)
  ( $DC "$@" build backend >"$LOG" 2>&1; echo "MORPHO_EXIT=$?" >>"$LOG" ) &
  pid=$!
  spin='|/-\'
  i=0; start=$(date +%s); pct=0
  while kill -0 "$pid" 2>/dev/null; do
    # Solo backend -> tokens [M/N] monotonos. Tomamos el ultimo y nunca retrocede.
    step=$(grep -oE '[0-9]+/[0-9]+\]' "$LOG" 2>/dev/null | tail -1)
    if [ -n "$step" ]; then
      m=${step%/*}; n=${step#*/}; n=${n%]}
      if [ "$n" -gt 0 ] 2>/dev/null; then
        new=$(( m * 100 / n ))
        [ "$new" -gt "$pct" ] && pct=$new
      fi
    fi
    el=$(( $(date +%s) - start ))
    c=$(printf '%s' "$spin" | cut -c $(( i % 4 + 1 )))
    printf '\r  %s  build  [%s] %3d%%   %ss  ' "$c" "$(_bar "$pct")" "$pct" "$el"
    i=$(( i + 1 )); sleep 0.2
  done
  printf '\r\033[K'
  code=$(grep -oE 'MORPHO_EXIT=[0-9]+' "$LOG" | tail -1 | cut -d= -f2)
  if [ "$code" = "0" ]; then
    printf '  \033[32m✓\033[0m build completo (%ss)\n' "$(( $(date +%s) - start ))"
    rm -f "$LOG"
  else
    printf '  \033[31m✗\033[0m el build fallo. Ultimas lineas:\n\n'
    tail -25 "$LOG"
    exit 1
  fi
}

# Frontend: trivial y rapido, sin barra.
printf '  preparando frontend...'
if $DC build frontend >/dev/null 2>&1; then printf '\r\033[K'; else printf '\n  fallo el build del frontend\n'; exit 1; fi

echo "MORPHO - detectando hardware..."

# 1) NVIDIA  2) AMD ROCm (experimental, Linux)  3) CPU (lento)
if docker run --rm --gpus all hello-world >/dev/null 2>&1; then
  echo "  GPU NVIDIA detectada -> con GPU"
  build_pretty -f docker-compose.yml -f docker-compose.gpu.yml
  $DC -f docker-compose.yml -f docker-compose.gpu.yml up -d
elif [ -e /dev/kfd ]; then
  echo "  GPU AMD (ROCm, experimental) -> con GPU"
  build_pretty -f docker-compose.yml -f docker-compose.amd.yml
  $DC -f docker-compose.yml -f docker-compose.amd.yml up -d
else
  echo "  Sin GPU -> CPU (la generacion sera lenta)"
  build_pretty
  $DC up -d
fi

echo ""
echo "Abri -> http://localhost:8080"
echo "Logs  -> $DC logs -f backend     (ver build completo: ./run.sh -v)"
