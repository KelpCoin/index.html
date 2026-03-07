# TODAY_ACTION_PLAN_PEGGY

## Mission
Install governance and verification layers so operations remain autonomous and auditable.

## Time-Boxed Actions
1. **00:00-00:30** Add approvals framework:
   - Create `approvals/APPROVAL_TEMPLATE.md`
   - Add simple policy note in `runbooks/daily-ops.md`.
2. **00:30-01:00** Enable scheduled verification:
   - `schtasks /Create /SC DAILY /TN "ClosureSweepVerify" /TR "powershell -ExecutionPolicy Bypass -File Verify_ClosureSweep.ps1" /ST 08:00`
3. **01:00-01:30** Add proof-hash workflow plan:
   - Draft `scripts/hash-ledger.ps1` spec in `AUTOMATION_GAPS.md` status notes.
4. **01:30-02:00** Validate closure pack integrity:
   - Run verifier and inspect logs in `logs/`.
5. **02:00-02:30** Prepare clone-on-paid-signal skeleton:
   - Create `runbooks/clone-on-paid-signal.md` with exact copy/checklist protocol.

## Definition of Done (Today)
- Approval template exists.
- Scheduled verify task is registered.
- Verification logs generated and reviewed.
