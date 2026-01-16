$ErrorActionPreference = "Stop"

$ComfyRoot = "D:\ComfyUI"
$ModelsPath = Join-Path $ComfyRoot "models"
$TempBackup = Join-Path $ComfyRoot "_models_backup"
$RepoUrl = "https://github.com/comfyanonymous/ComfyUI.git"

Write-Host "[Cortex] Starting ComfyUI clean reinstall" -ForegroundColor Yellow

if (Test-Path $ModelsPath) {
    if (Test-Path $TempBackup) {
        Remove-Item $TempBackup -Recurse -Force
    }
    Move-Item $ModelsPath $TempBackup
}

if (Test-Path $ComfyRoot) {
    Get-ChildItem -Path $ComfyRoot -Force | ForEach-Object {
        if ($_.Name -ne "models" -and $_.Name -ne "_models_backup") {
            Remove-Item $_.FullName -Recurse -Force
        }
    }
}

if (-not (Test-Path $ComfyRoot)) {
    New-Item -ItemType Directory -Path $ComfyRoot | Out-Null
}

Set-Location $ComfyRoot

git clone $RepoUrl .

if (Test-Path $TempBackup) {
    if (Test-Path $ModelsPath) {
        Remove-Item $ModelsPath -Recurse -Force
    }
    Move-Item $TempBackup $ModelsPath
}

python -m venv venv

$VenvPython = Join-Path $ComfyRoot "venv\Scripts\python.exe"
$VenvPip = Join-Path $ComfyRoot "venv\Scripts\pip.exe"

& $VenvPip install --upgrade pip
& $VenvPip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
& $VenvPip install -r requirements.txt

$LaunchBat = Join-Path $ComfyRoot "Comfy_Launch.bat"
@"
@echo off
cd /d $ComfyRoot
call venv\Scripts\activate.bat
python main.py --listen 0.0.0.0 --port 8188
"@ | Set-Content -Path $LaunchBat -Encoding ASCII

$PalettePath = Join-Path $ComfyRoot "cortex_palette.json"
@"
{
  "name": "Retro Sega Mega Drive",
  "colors": ["#000000","#1B0A3A","#3C0078","#7800A8","#A80078","#F80000","#F8A800","#F8F800","#78F800","#00F800","#00A878","#007878","#003C78","#001B3A","#FF66CC"],
  "peg_pink_accent": "#FF66CC"
}
"@ | Set-Content -Path $PalettePath -Encoding UTF8

$ProfilePath = Join-Path $ComfyRoot "cortex_output_profile.json"
@"
{
  "overlay": {
    "safe_zone": "85%",
    "font": "pixel",
    "outline": "2px",
    "shadow": "40% black",
    "accent": "#FF66CC"
  },
  "tone": "Peggy-Mod warm, indulgent, body-positive."
}
"@ | Set-Content -Path $ProfilePath -Encoding UTF8

if (-not (Test-Path (Join-Path $ComfyRoot "main.py"))) {
    throw "main.py missing after install"
}

& $VenvPython - <<'PY'
import torch
print(torch.__version__)
PY

$PortOpen = $false
$Listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, 8188)
try {
    $Listener.Start()
    $PortOpen = $true
} catch {
    $PortOpen = $false
} finally {
    $Listener.Stop()
}

if (-not $PortOpen) {
    throw "Port 8188 is not available"
}

Start-Process -FilePath $LaunchBat
Write-Host "[Cortex] ComfyUI reinstall complete." -ForegroundColor Green
