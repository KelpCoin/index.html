@echo off
setlocal

echo [ClosureSweep] Running installer...
powershell -ExecutionPolicy Bypass -File "%~dp0Install_ClosureSweep.ps1"
if errorlevel 1 goto :fail

echo [ClosureSweep] Running verifier...
powershell -ExecutionPolicy Bypass -File "%~dp0Verify_ClosureSweep.ps1"
if errorlevel 1 goto :fail

echo [ClosureSweep] Complete.
exit /b 0

:fail
echo [ClosureSweep] Failed.
exit /b 1
