# CRITICAL_MISSING_PIECES

## P0 Missing Pieces (Blockers)
1. `docs/decision-log/` canonical history (memory still trapped in chat).
2. `runbooks/daily-ops.md` for deterministic daily execution.
3. `ledgers/revenue-ledger.csv` and `ledgers/experiment-ledger.csv`.
4. `approvals/APPROVAL_TEMPLATE.md` and required usage policy.
5. Scheduled verification and proof hash generation.

## P1 Missing Pieces
1. Clone playbook for paid-signal replication.
2. Offer messaging library with approved scripts.
3. KPI dashboard (local CSV + minimal script summary).

## Acceptance Criteria to Exit Critical State
- All P0 files exist locally.
- `Verify_ClosureSweep.ps1` passes with zero missing required artifacts.
- One scheduled daily verify job is active.
- At least one monetization lane has live KPI updates in local ledger.
