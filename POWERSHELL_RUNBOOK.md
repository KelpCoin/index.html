# POWERSHELL RUNBOOK

## Environment standard
- Windows 11
- PowerShell 5.1
- ASCII-only files

## Primary commands
- Install: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install_PhaseoutPack.ps1`
- Verify: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verify_PhaseoutPack.ps1`
- Launcher: double-click `Run_PhaseoutPack.cmd`

## Expected outputs per meaningful run
- log file path
- proof file path
- JSONL ledger path
- one-line verifier command

## Troubleshooting
1. If D drive unavailable, confirm fallback paths on C drive.
2. If proof missing, rerun installer and inspect log.
3. If ledger missing, stop and fix before any public action.
4. If approval check fails, block action until explicit approval record exists.
