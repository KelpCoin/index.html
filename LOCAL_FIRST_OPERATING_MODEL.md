# Local-First Operating Model

## Platform baseline
- Windows 11
- PowerShell 5.1
- ASCII-only artifacts

## Storage baseline
- Primary: D:\BrownEyeCortex and D:\BrownEyeCortexData
- Fallback: C:\BrownEyeCortex and C:\BrownEyeCortexData

## Reliability baseline
- Idempotent scripts
- Archive/replace behavior
- No surprise window closes where practical
- Every meaningful run emits proof and ledger entry

## Execution pattern
1. Install or update with Install_PhaseoutPack.ps1
2. Validate with Verify_PhaseoutPack.ps1
3. Use runbooks and action plans from local markdown files
4. Track all meaningful runs in JSONL ledger

## Operator load control
- Favor batch commands
- Minimize manual edits
- Keep docs canonical and short
- Keep commands copy-safe and deterministic
