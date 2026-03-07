@echo off
setlocal

set ROOT=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Query_MemoryVault.ps1" %*

endlocal
