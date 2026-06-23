# MORPHO - launcher Windows. Detecta GPU y version de Compose; levanta con o sin GPU.
Write-Host ""

# Detecta Compose v2 ("docker compose") vs v1 ("docker-compose").
$useV2 = $false
docker compose version *> $null
if ($LASTEXITCODE -eq 0) {
    $useV2 = $true
} elseif (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Compose no encontrado. Instala Docker Desktop." -ForegroundColor Red
    exit 1
}
function Compose { if ($useV2) { docker compose @args } else { docker-compose @args } }

Write-Host "MORPHO - detectando GPU NVIDIA..." -ForegroundColor Cyan

# Test liviano: --gpus all dispara el hook NVIDIA. Si no hay GPU, falla (exit != 0).
docker run --rm --gpus all hello-world *> $null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  GPU NVIDIA detectada -> levantando CON GPU" -ForegroundColor Green
    Compose -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
} else {
    Write-Host "  Sin GPU NVIDIA accesible -> levanto igual (la app avisara en pantalla)" -ForegroundColor Yellow
    Compose up -d --build
}

Write-Host ""
Write-Host "Abri -> http://localhost:8080" -ForegroundColor Cyan
Write-Host "Logs  -> docker compose logs -f backend" -ForegroundColor DarkGray
