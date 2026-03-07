# PowerShell Runbook

## Launch commands
- Install:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_PhaseoutPack.ps1
- Verify:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Verify_PhaseoutPack.ps1
- Combined launcher:
  .\Run_PhaseoutPack.cmd

## Expected outputs
- Log file path
- Proof file path
- Ledger file path
- Verifier command

## Fast diagnostics
1. Confirm D:\ exists; if not, expect C:\ fallback.
2. Confirm ledger file receives new JSONL line.
3. Confirm proof file timestamp is current run.
4. Confirm required markdown files exist under selected root.

## Idempotent rerun behavior
- Existing files are archived with timestamp.
- New files replace canonical names.
- Ledger appends a new run entry.
