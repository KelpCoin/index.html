@echo off
setlocal
set SCRIPT_DIR=%~dp0

echo [BrownEye] Running Phaseout Pack install...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install_PhaseoutPack.ps1"
if errorlevel 1 (
  echo [BrownEye] Install failed.
  echo Press any key to close.
  pause >nul
  exit /b 1
)

echo [BrownEye] Running Phaseout Pack verify...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Verify_PhaseoutPack.ps1"
if errorlevel 1 (
  echo [BrownEye] Verify failed.
  echo Press any key to close.
  pause >nul
  exit /b 1
)

echo [BrownEye] Completed install and verify.
echo Press any key to close.
pause >nul
exit /b 0
