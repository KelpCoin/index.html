$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$PythonExe = Join-Path $RepoRoot "venv\Scripts\python.exe"
$Requirements = Join-Path $RepoRoot "requirements.txt"

if (-not (Test-Path $PythonExe)) {
    python -m venv (Join-Path $RepoRoot "venv")
    & $PythonExe -m pip install --upgrade pip
    & $PythonExe -m pip install -r $Requirements
}

& $PythonExe (Join-Path $RepoRoot "cortex\orchestrator.py")
