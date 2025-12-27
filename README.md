# BrownEye Cortex Automation Enhancements

This repository adds three mandatory capabilities to the BrownEye Cortex while
keeping the existing automation behavior intact. Everything is implemented with
standard Python modules and is safe to run repeatedly (idempotent) across
platforms via a lightweight Windows-path mirror helper.

## Path mirroring and portability
All required files are defined with their Windows paths. On Windows, the helpers
write to the real locations. On other platforms, the paths are mirrored under a
local `cortex_mirror/` directory (override with `CORTEX_WINDOWS_MIRROR`). This
makes development and testing cross-platform without new dependencies.

## 1) Change Journal (mandatory)
- **Helper:** `cortex/change_journal.py`
- **Target file:** `C:\BrownEyeCortex\Logs\System\change_journal.log`
- **Behavior:** Every script calls `ChangeJournal.log_change(...)` when a change
  occurs or `log_no_material_change(...)` if nothing changed. Entries are
  timestamped (UTC) and include the module, what changed, category, and whether
  it was auto-applied or human-approved.

### Example entries
Stored in `examples/change_journal.log`:
```
[2024-12-27T01:00:00Z UTC] module=build_bot category=file item=primer files refreshed mode=auto-applied
[2024-12-27T01:05:00Z UTC] module=queue_runner no material change
```

## 2) "Ask When Unsure" governance gate (mandatory)
- **Helper:** `cortex/governance.py`
- **Config:** `C:\BrownEyeCortex\Data\System\governance.json` is created with
  defaults if missing:
  ```json
  {
    "ask_when_unsure": true,
    "confidence_threshold": 0.65
  }
  ```
- **Pending requests:** risky/low-confidence actions are paused and written to
  `C:\BrownEyeCortex\Logs\Approvals\pending_requests.jsonl` instead of failing.
  A Discord webhook is notified when `CORTEX_DISCORD_WEBHOOK` is set.
- **Usage:** call `GovernanceGate.guard(context)` before making a change. When it
  returns `True`, the action is paused and should not proceed.

### Example pending request
See `examples/pending_requests.jsonl`:
```
{"timestamp": "2024-12-27T01:10:00Z", "job_name": "arbitrage_analysis", "confidence": 0.55, "touches_money": true, "overwrites_files": false, "deletes_data": false, "changes_behavior": true, "summary": "Would place a new order on low confidence signal", "metadata": {"pair": "USD/EUR"}, "status": "pending-approval"}
```

## 3) Self-explanation output (mandatory)
- **Helper:** `cortex/explanations.py`
- **Target files:** `C:\BrownEyeCortex\Logs\Explanations/<jobname>_<timestamp>.json`
- **Behavior:** Each job writes a short structured explanation describing what
  was done, the decision, risk level, confidence, and a 2–3 sentence human
  summary.

### Example explanation
Saved in `examples/Explanations/queue_runner_20241227T011500Z.json`:
```json
{
  "timestamp": "20241227T011500Z",
  "job_type": "queue_run",
  "input_summary": "Processed 42 queued tasks",
  "decision": "Executed tasks and rescheduled 3 retries",
  "risk_level": "low",
  "confidence": 0.93,
  "human_summary": "Queue runner executed the pending tasks and safely retried a few failures. No sensitive files or payouts were touched.",
  "metadata": {
    "retry_count": 3
  }
}
```

## Putting it together
`sample_job.py` shows how a Cortex job can combine the helpers:
1. Build a `GovernanceContext` describing the action.
2. Call `GovernanceGate.guard(...)` to pause risky changes and create a pending
   approval request.
3. Record either `log_no_material_change` (paused) or `log_change` (executed).
4. Emit a self-explanation via `ExplanationWriter.write(...)`.

Each helper is reusable by existing queue runners, build bots, arbitrage
analysis, and primer generators without altering their core logic.
