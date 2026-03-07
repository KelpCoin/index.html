# AUTOMATION_GAPS

| Gap ID | Missing Automation | Impact | Current Manual Work | Proposed Script/Job | Priority |
|---|---|---|---|---|---|
| AG-001 | Daily integrity verify scheduling | Drift may go unnoticed | Manual run of verifier | Windows Task Scheduler job for `Verify_ClosureSweep.ps1` | P0 |
| AG-002 | Artifact hashing | No tamper-evidence proofs | None | `scripts/hash-ledger.ps1` -> `proofs/sha256-<date>.txt` | P0 |
| AG-003 | Decision-log template bootstrap | Inconsistent canonization | Manual markdown writing | `scripts/new-decision-log.ps1` | P1 |
| AG-004 | Approval gate enforcement | Unreviewed risky edits | Human memory | pre-commit hook checking approval file ref | P1 |
| AG-005 | Revenue ledger update helper | Delayed KPI visibility | Spreadsheet edits | `scripts/add-revenue-entry.ps1` | P2 |
| AG-006 | Clone-on-paid-signal scaffolding | Slow replication | Manual copy/paste | `scripts/clone-lane.ps1` | P2 |

## Required Command Lines
```powershell
schtasks /Create /SC DAILY /TN "ClosureSweepVerify" /TR "powershell -ExecutionPolicy Bypass -File Verify_ClosureSweep.ps1" /ST 08:00
```

```powershell
# Planned (to implement)
powershell -ExecutionPolicy Bypass -File .\scripts\hash-ledger.ps1
```
