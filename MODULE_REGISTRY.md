# MODULE_REGISTRY

| Module | Path | Purpose | Local? | Proof/Log Present? | Verifier | Approval Gate |
|---|---|---|---|---|---|---|
| Landing page | `index.html` | Form capture page | Yes | No | None | Missing |
| Closure sweep report | `CLOSURE_SWEEP_REPORT.md` | Master closure state | Yes | N/A | `Verify_ClosureSweep.ps1` heading check | Missing |
| Open loops register | `OPEN_LOOPS_REGISTER.md` | Loop closure queue | Yes | N/A | File presence check | Missing |
| Money ideas register | `MONEY_IDEAS_REGISTER.md` | Monetization backlog | Yes | N/A | File presence check | Missing |
| Module registry | `MODULE_REGISTRY.md` | Module inventory | Yes | N/A | File presence check | Missing |
| Automation gaps | `AUTOMATION_GAPS.md` | Missing automation inventory | Yes | N/A | File presence check | Missing |
| Critical missing pieces | `CRITICAL_MISSING_PIECES.md` | Blocking gaps | Yes | N/A | File presence check | Missing |
| Local replacements plan | `LOCAL_REPLACEMENTS_PLAN.md` | ChatGPT replacement map | Yes | N/A | File presence check | Missing |
| Biggie action plan | `TODAY_ACTION_PLAN_BIGGIE.md` | Operator action checklist | Yes | N/A | File presence check | Missing |
| Peggy action plan | `TODAY_ACTION_PLAN_PEGGY.md` | Operator action checklist | Yes | N/A | File presence check | Missing |
| Installer script | `Install_ClosureSweep.ps1` | Setup local structure/logs | Yes | Install log generated | Manual + verify | Missing |
| Verifier script | `Verify_ClosureSweep.ps1` | Validate closure pack integrity | Yes | Verify log generated | Self-verifying | Missing |
| Launcher | `Run_ClosureSweep.cmd` | One-command execution | Yes | Command output | Manual | Missing |
