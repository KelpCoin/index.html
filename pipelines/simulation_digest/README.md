# Simulation Digest Pipeline

Aggregates simulation JSON outputs into a weekly Markdown digest with upsell CTAs and gated publish stubs for Patreon/Discord.

## Run
```powershell
pwsh -File .\pipelines\simulation_digest\orchestrate_simulation_digest.ps1 -ConfigPath .\pipelines\simulation_digest\config.simulation_digest.json
```
Use `-DryRun` to skip file writes while keeping logs.

## Inputs
- Place simulation JSON files under `pipelines/simulation_digest/data/simulations`.

## Outputs
- Markdown digest files + metadata JSON in `pipelines/simulation_digest/output`.
- Listing text under `pipelines/simulation_digest/listings`.
- Logs at `pipelines/logs/simulation_digest.log` and next run schedule in `output/next_run.txt`.
