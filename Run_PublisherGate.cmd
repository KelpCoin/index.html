@echo off
setlocal

set ROOT=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Install_PublisherGate.ps1"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Verify_PublisherGate.ps1"
if errorlevel 1 exit /b 1

if exist "D:\Publisher\List-PendingPublicActions.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "D:\Publisher\List-PendingPublicActions.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Publisher\List-PendingPublicActions.ps1"
)

endlocal
