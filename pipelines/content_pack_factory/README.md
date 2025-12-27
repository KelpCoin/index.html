# Content Pack Factory

Builds themed tactical packs from seed ideas, packaging them with affiliate hooks and storefront listings.

## Run
```powershell
pwsh -File .\pipelines\content_pack_factory\orchestrate_content_pack.ps1 -ConfigPath .\pipelines\content_pack_factory\config.content_pack.json
```
Add `-DryRun` to skip writes.

## Inputs
- Seed text files in `pipelines/content_pack_factory/data/seeds` (auto-seeded if empty).

## Outputs
- Pack Markdown + metadata + zip in `pipelines/content_pack_factory/output`.
- Listing text in `pipelines/content_pack_factory/listings`.
- Logs at `pipelines/logs/content_pack.log` and schedule in `output/next_run.txt`.
