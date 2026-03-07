@echo off
setlocal
set SCRIPT_DIR=%~dp0

echo Running Phaseout Pack installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install_PhaseoutPack.ps1"

echo.
echo Running Phaseout Pack verifier...
if exist D:\BrownEyeCortex\PhaseoutPack\current\Verify_PhaseoutPack.ps1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\BrownEyeCortex\PhaseoutPack\current\Verify_PhaseoutPack.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\BrownEyeCortex\PhaseoutPack\current\Verify_PhaseoutPack.ps1"
)

echo.
echo Phaseout pack run complete. Review output above.
echo Window intentionally kept open.
cmd /k
