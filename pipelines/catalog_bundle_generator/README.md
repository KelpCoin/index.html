# Catalog → Bundle Generator

Builds new bundles by reading existing metadata across pipelines and emitting bundle products plus listings.

## Run
```powershell
pwsh -File .\pipelines\catalog_bundle_generator\orchestrate_bundle_generator.ps1 -ConfigPath .\pipelines\catalog_bundle_generator\config.bundle_generator.json
```
Use `-DryRun` to preview without writes.

## Inputs
- Metadata JSON files under the configured catalog roots (defaults: outputs of other pipelines).

## Outputs
- Bundle Markdown + metadata in `pipelines/catalog_bundle_generator/output`.
- Listing text in `pipelines/catalog_bundle_generator/listings`.
- Logs at `pipelines/logs/catalog_bundle.log` and schedule in `output/next_run.txt`.
