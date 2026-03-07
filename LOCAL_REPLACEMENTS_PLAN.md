# LOCAL_REPLACEMENTS_PLAN

## ChatGPT Dependency -> Local Replacement Map

| Dependency Pattern | Current Risk | Local Replacement | File/Path | Owner | Deadline |
|---|---|---|---|---|---|
| “Ask ChatGPT for next step” | Workflow stalls after account closure | Deterministic runbook + daily checklist | `runbooks/daily-ops.md` | Biggie | Today |
| “Ask ChatGPT to summarize strategy” | Strategic memory loss | Decision log canon | `docs/decision-log/2026-closure-canon.md` | Biggie | Today |
| “Ask ChatGPT for monetization priorities” | Revenue focus drifts | Ranked money register + KPI owner | `MONEY_IDEAS_REGISTER.md` + ledgers | Peggy | Today |
| “Ask ChatGPT to verify completeness” | Quality gate missing | `Verify_ClosureSweep.ps1` + scheduled run | `Verify_ClosureSweep.ps1` | Peggy | Tomorrow |
| “Ask ChatGPT for deployment safety” | Unapproved risky changes | Approval template + required gate | `approvals/APPROVAL_TEMPLATE.md` | Peggy | Tomorrow |

## Rebuild Locally First (Order)
1. Decision canon.
2. Runbooks.
3. Ledgers.
4. Approval gates.
5. Automation scripts.
6. Clone/scale scripts.

## Operator Command Baseline
```powershell
powershell -ExecutionPolicy Bypass -File .\Install_ClosureSweep.ps1
powershell -ExecutionPolicy Bypass -File .\Verify_ClosureSweep.ps1
```
