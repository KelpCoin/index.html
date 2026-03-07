@echo off
setlocal
set SCRIPT_DIR=%~dp0

echo Running Codex Spine verifier (window remains open)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Verify_CodexSpine.ps1"

echo.
echo Verifier command:
echo powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Verify_CodexSpine.ps1

echo.
echo Press any key to close.
pause >nul
endlocal
