# Deck Funeral + Upgrade Pipeline

Turns uploaded decklists into funeral reports with upgrade suggestions, affiliate links, and Gumroad-ready zips.

## Run
```powershell
pwsh -File .\pipelines\deck_funeral_upgrade\orchestrate_deck_funeral.ps1 -ConfigPath .\pipelines\deck_funeral_upgrade\config.deck_funeral.json
```
Use `-DryRun` to log without writing files.

## Inputs
- Decklist `.txt` files inside `pipelines/deck_funeral_upgrade/data/decklists` (auto-seeded with a sample if empty).

## Outputs
- Funeral report Markdown, metadata JSON, and zipped product in `pipelines/deck_funeral_upgrade/output`.
- Listing text in `pipelines/deck_funeral_upgrade/listings`.
- Logs in `pipelines/logs/deck_funeral.log` and schedule in `output/next_run.txt`.
