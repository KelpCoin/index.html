$ErrorActionPreference = "Stop"

$TaskName = "BiggieBrownEyeCortex"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$PythonExe = Join-Path $RepoRoot "venv\Scripts\python.exe"
$Orchestrator = Join-Path $RepoRoot "cortex\orchestrator.py"

if (-not (Test-Path $PythonExe)) {
    throw "Python venv not found. Create venv and install requirements first."
}

$Action = New-ScheduledTaskAction -Execute $PythonExe -Argument $Orchestrator -WorkingDirectory $RepoRoot
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Force
Start-ScheduledTask -TaskName $TaskName
Write-Host "[Cortex] Scheduled task installed and started: $TaskName" -ForegroundColor Green
