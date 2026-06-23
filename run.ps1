# MORPHO - launcher Windows. Detecta hardware + Compose y hace el build con una
# barra de progreso animada (sin dependencias). Logs ocultos por defecto.
#   .\run.ps1        -> lindo (barra + %), logs escondidos
#   .\run.ps1 -v     -> muestra los logs completos del build (desplegar)
param([switch]$v)

Write-Host ""

# --- Detecta Compose v2 ("docker compose") vs v1 ("docker-compose") ---
$useV2 = $false
docker compose version *> $null
if ($LASTEXITCODE -eq 0) {
    $useV2 = $true
} elseif (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Compose no encontrado. Instala Docker Desktop." -ForegroundColor Red
    exit 1
}
function Compose { if ($useV2) { docker compose @args } else { docker-compose @args } }

function Get-Bar([int]$pct) {
    $filled = [int]($pct * 24 / 100)
    return ('#' * $filled) + ('.' * (24 - $filled))
}

# --- Build con barra animada. $cargs = args de compose (-f ...). ---
function Build-Pretty([string[]]$cargs) {
    if ($v) {
        Compose @cargs build backend
        if ($LASTEXITCODE -ne 0) { exit 1 }
        return
    }

    $job = Start-Job -ScriptBlock {
        param($useV2, $cargs, $wd)
        Set-Location $wd
        if ($useV2) { docker compose @cargs build backend 2>&1 } else { docker-compose @cargs build backend 2>&1 }
        "MORPHO_EXIT=$LASTEXITCODE"
    } -ArgumentList $useV2, $cargs, (Get-Location).Path

    $spin = '|', '/', '-', '\'
    $i = 0; $sw = [System.Diagnostics.Stopwatch]::StartNew(); $pct = 0
    while ($job.State -eq 'Running') {
        $out = Receive-Job $job -Keep 2>$null
        if ($out) {
            $mm = [regex]::Matches(($out -join "`n"), '(\d+)/(\d+)\]')
            if ($mm.Count -gt 0) {
                $g = $mm[$mm.Count - 1].Groups
                $tot = [int]$g[2].Value
                if ($tot -gt 0) {
                    $new = [int]([int]$g[1].Value * 100 / $tot)
                    if ($new -gt $pct) { $pct = $new }   # monotono, nunca retrocede
                }
            }
        }
        $sec = [int]$sw.Elapsed.TotalSeconds
        Write-Host ("`r  {0}  build  [{1}] {2,3}%   {3}s  " -f $spin[$i % 4], (Get-Bar $pct), $pct, $sec) -NoNewline
        $i++; Start-Sleep -Milliseconds 200
    }

    $all = Receive-Job $job
    Remove-Job $job
    Write-Host ("`r" + (' ' * 64) + "`r") -NoNewline

    if (("$all" | Select-String 'MORPHO_EXIT=0')) {
        Write-Host ("  " + [char]0x2713 + " build completo ({0}s)" -f [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host "  X el build fallo. Ultimas lineas:" -ForegroundColor Red
        ($all | Select-Object -Last 25) | ForEach-Object { Write-Host $_ }
        exit 1
    }
}

# Limpia contenedores previos (evita "container name already in use" y deja el
# front nuevo en uso). down por nombre de proyecto, sin importar con que -f se creo.
Compose down --remove-orphans *> $null

# Frontend: trivial y rapido, sin barra.
Write-Host "  preparando frontend..." -NoNewline
Compose build frontend *> $null
if ($LASTEXITCODE -ne 0) { Write-Host "`n  fallo el build del frontend" -ForegroundColor Red; exit 1 }
Write-Host ("`r" + (' ' * 30) + "`r") -NoNewline

Write-Host "MORPHO - detectando hardware..." -ForegroundColor Cyan

# --gpus all dispara el hook NVIDIA. (AMD/ROCm no corre en Windows -> NVIDIA o CPU.)
docker run --rm --gpus all hello-world *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  GPU NVIDIA detectada -> con GPU" -ForegroundColor Green
    Build-Pretty @('-f', 'docker-compose.yml', '-f', 'docker-compose.gpu.yml')
    Compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
} else {
    Write-Host "  Sin GPU -> CPU (la generacion sera lenta)" -ForegroundColor Yellow
    Build-Pretty @()
    Compose up -d
}

Write-Host ""
Write-Host "Abri -> http://localhost:8080" -ForegroundColor Cyan
Write-Host "Logs  -> docker compose logs -f backend     (ver build completo: .\run.ps1 -v)" -ForegroundColor DarkGray
