# CLOSURE_SWEEP_REPORT

## Scope
This sweep assumes the ChatGPT account may be closed **today**. Goal: preserve operational continuity via local files, local rules, local scripts, local proofs, local ledgers, and local launchers.

## Snapshot (Current State)
- Repository path: `C:\workspace\index.html` (mirrors `/workspace/index.html` in current shell).
- Detected source assets:
  - `index.html`
- Detected closure assets added by this sweep:
  - `CLOSURE_SWEEP_REPORT.md`
  - `OPEN_LOOPS_REGISTER.md`
  - `MONEY_IDEAS_REGISTER.md`
  - `MODULE_REGISTRY.md`
  - `AUTOMATION_GAPS.md`
  - `CRITICAL_MISSING_PIECES.md`
  - `LOCAL_REPLACEMENTS_PLAN.md`
  - `TODAY_ACTION_PLAN_BIGGIE.md`
  - `TODAY_ACTION_PLAN_PEGGY.md`
  - `Install_ClosureSweep.ps1`
  - `Verify_ClosureSweep.ps1`
  - `Run_ClosureSweep.cmd`

## Explicit ChatGPT-Dependency Check
### Still depends on ChatGPT (high risk)
1. **Strategic memory not canonized**
   - Product strategy, pricing hypotheses, customer objections, script rationale likely exist in prior chats only.
   - No `docs/decision-log/` or equivalent local narrative history was found.
2. **Execution prompting loop**
   - No local prompt-to-procedure replacement (no SOP tree, no deterministic checklist executor).
3. **No local agent runbook for recurring tasks**
   - No `runbooks/` folder with launch commands and acceptance criteria.

### Already local (low/medium risk)
1. `index.html` landing page/form embed exists locally.
2. Closure sweep pack files now exist locally.
3. PowerShell + CMD launchers now exist locally to run installation and verification.

## Must-Rebuild-Locally-First (priority order)
1. **Decision Canon** (`docs/decision-log/*.md`)
2. **Operator SOPs** (`runbooks/*.md`)
3. **Proof/ledger layer** (`proofs/`, `logs/`, `ledgers/`)
4. **Module approval gates** (`approvals/` with required sign-off template)
5. **Automated verifiers** (`scripts/verify/*.ps1`)

## Monetization Lanes Nearest Paid Signal
Ranked by shortest path to measurable revenue evidence:
1. **KelpCoin claim funnel optimization service**
   - Paid signal: client pays for setup + conversion audit.
   - Immediate metric: form submissions/day and verified wallet quality.
2. **Micro-funnel build package (single-page lead capture)**
   - Paid signal: one-time implementation fee per funnel.
   - Immediate metric: number of delivered pages + lead capture rates.
3. **Ops hardening add-on (closure pack + verification scripts)**
   - Paid signal: paid handoff for “vendor lock-out resilience” kit.
   - Immediate metric: closed delivery count and acceptance checklist pass rate.

## Scripts Missing Proofs/Logs/Verifiers
- Prior to this sweep: all scripts missing (none existed).
- Current status:
  - `Install_ClosureSweep.ps1`: creates folders/files, writes install log.
  - `Verify_ClosureSweep.ps1`: checks required artifacts and headings, writes verify log.
  - `Run_ClosureSweep.cmd`: one-click launcher.
- Remaining gap: no scheduled execution and no immutable ledger hash snapshots.

## Modules Missing Approval Gates
All modules currently lack explicit approval gates:
- Landing page (`index.html`)
- Registers (`*_REGISTER.md`)
- Plans (`*_PLAN*.md`)
- Automation scripts (`*.ps1`, `*.cmd`)

Required gate to add:
- `approvals/APPROVAL_TEMPLATE.md` with fields:
  - module
  - change summary
  - risk level
  - rollback command
  - approver signature/date

## Memory Trapped in Chat (to canonize now)
- Offer positioning language.
- “BrownEye closure” criteria and why each check matters.
- Reusable objection-handling responses.
- Pricing confidence thresholds and discount guardrails.
- Past experiments and outcomes (including failures).

## Kill Immediately (to reduce load)
1. Any workflow step that says “ask ChatGPT what to do next.”
2. Any undocumented recurring task with no local runbook.
3. Ad-hoc copy variants not tied to measured KPI.

## Clone If Paid Evidence Appears
If any lane hits one paid conversion, clone the exact stack:
- Copy module folder to `clones/<lane>/<YYYY-MM-DD>/`
- Duplicate:
  - offer page template
  - follow-up script templates
  - verification script
  - ledger schema
- Preserve same acceptance checks before introducing variation.

## Priority-Ranked Fix List (Concrete)
1. Create `docs/decision-log/2026-closure-canon.md` and backfill last 20 key decisions.
2. Create `runbooks/daily-ops.md` with exact start/stop commands.
3. Create `ledgers/revenue-ledger.csv` and `ledgers/experiment-ledger.csv`.
4. Add `approvals/APPROVAL_TEMPLATE.md` and require approval before deploy edits.
5. Add `scripts/hash-ledger.ps1` to hash artifacts into `proofs/sha256-<date>.txt`.
6. Add scheduled task:
   - `schtasks /Create /SC DAILY /TN "ClosureSweepVerify" /TR "powershell -ExecutionPolicy Bypass -File Verify_ClosureSweep.ps1" /ST 08:00`

## Immediate Commands
```powershell
powershell -ExecutionPolicy Bypass -File .\Install_ClosureSweep.ps1
powershell -ExecutionPolicy Bypass -File .\Verify_ClosureSweep.ps1
```

```cmd
Run_ClosureSweep.cmd
```
