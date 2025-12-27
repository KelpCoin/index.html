# BrownEye Monetisation Pipelines

This repository ships four PowerShell pipelines that convert BrownEye outputs into sale-ready products with built-in NZD pricing, affiliate hooks, and repeatable schedules. Each pipeline is idempotent and leans on shared modules under `pipelines/common`.

## Pipelines
1. **Simulation Digest Pipeline** – Aggregates simulation JSON files into weekly digests with Patreon/Discord gating.
2. **Deck Funeral + Upgrade Pipeline** – Turns uploaded decklists into funeral reports, upgrade suggestions, and Gumroad-ready bundles.
3. **Content Pack Factory** – Generates recurring themed content packs from idea seeds and prepares storefront listings.
4. **Catalog → Bundle Generator** – Reads existing metadata to assemble bundled offers automatically.

## Quickstart
- Environment: Windows with PowerShell 5+ or pwsh 7+.
- Optional env vars: `PATREON_TOKEN`, `DISCORD_WEBHOOK`, `GUMROAD_API_KEY`. Scripts will stub publishing when unset.
- Run any pipeline:
  ```powershell
  pwsh -File .\pipelines\simulation_digest\orchestrate_simulation_digest.ps1 -ConfigPath .\pipelines\simulation_digest\config.simulation_digest.json
  ```
- Outputs land under each pipeline's `output` directory with metadata, listings, logs, and next-run schedule.

## Shared patterns
- Templates live in each `templates` folder; common listing template is at `pipelines/common/templates/listing.md`.
- Logs: `pipelines/logs` hold timestamped entries per pipeline.
- Bundling: The catalog bundle generator reads `*.metadata.json` across pipelines to create new SKUs automatically.
