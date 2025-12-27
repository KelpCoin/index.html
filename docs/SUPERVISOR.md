# BrownEye Cortex Supervisor

The Supervisor wraps existing Cortex components (queue runner, arbitrage pipelines, LearnBot, dashboards, data lake, primer factory, policy JSONs, scheduled automations) with guardrails. It is defensive, idempotent, transparent, and always recoverable from disk.

## Architecture
- **Supervisor Daemon (`supervisor/supervisor_daemon.py`)**: watches policies/configs, tails health signals, restarts stalled processes, blocks tight loops, and rate-limits automation. Alerts go to Discord (via `SUPERVISOR_DISCORD_WEBHOOK`) and local logs (`supervisor/supervisor.log`).
- **Rollback Engine (`supervisor/rollback_engine.py`)**: versioned snapshot store for arbitrage policy, LearnBot suggestions, config files, and queue definitions. Snapshots are taken before promotion and can be reverted with human approval. History is persisted under `data/rollback/<subsystem>/history.log`.
- **Safety Rules (`supervisor/safety_rules.py`)**: codified constraints like transaction caps, protected directories, LearnBot confidence floors, auto-listing gating, and catastrophic profit-drop pauses.
- **Observability (`supervisor/observability.py`)**: writes health heartbeat JSON (`supervisor/heartbeat.json`), incident logs (`supervisor/incidents.log`), and plugs into dashboards via files on disk.
- **Self-tests (`supervisor/self_tests.py`)**: sanity probes to validate the supervisor’s own guardrails.
- **CLI (`supervisor/cli.py`) + PowerShell bridge (`scripts/supervisor.ps1`)**: human-overridable commands to inspect, freeze, rollback, and resume subsystems.

## Intervention Triggers
- **Crash or stale heartbeat**: subsystem is restarted and noted in the incident log.
- **Policy/config pending change**: evaluated against safety rules; unsafe changes are frozen; safe changes are snapshotted before promotion.
- **Runtime metrics**: exceeding transaction caps, catastrophic profit drops, or low LearnBot confidence create safety violations and trigger freezes until a human resumes.

## Rollback and Recovery
- Snapshots live under `data/rollback/<subsystem>/<timestamp>/` with the captured file and `meta.json` describing approval and rationale.
- To revert: `python -m supervisor.cli rollback <subsystem> --approved-by you` (uses `--to last-known-good` by default).
- Full recovery is possible from disk even without network because snapshots and logs are local-first.

## Operations
- Run daemon: `python -m supervisor.cli run`
- Check status: `python -m supervisor.cli status`
- Freeze a subsystem: `python -m supervisor.cli freeze learnbot`
- Unfreeze/resume: `python -m supervisor.cli resume all --approved-by <name>`
- Roll back: `python -m supervisor.cli rollback policy --approved-by <name>`
- PowerShell: use `scripts/supervisor.ps1` wrappers for Windows environments.

## Transparency and Human Control
- Every automated decision is logged with rationale in `supervisor/incidents.log` and mirrored to Discord when configured.
- All interventions are idempotent; repeating a freeze or rollback is safe because state is file-based and versioned.
- Humans can override by unfreezing subsystems or approving rollbacks via the CLI/PowerShell bridge.
