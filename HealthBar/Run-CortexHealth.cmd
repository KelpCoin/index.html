@echo off
setlocal
set SCRIPT_DIR=%~dp0
set LOG_DIR=%SCRIPT_DIR%logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set TS=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TS=%TS: =0%
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Get-CortexHealth.ps1" > "%LOG_DIR%\health_%TS%.log" 2>&1
if errorlevel 1 (
  echo Cortex health failed. Check log: %LOG_DIR%\health_%TS%.log
  exit /b 1
)
echo Cortex health complete. Log: %LOG_DIR%\health_%TS%.log
exit /b 0
