# BrownEye Closed-Loop Factory Template

## Core Pattern
- Config: `C:/BrownEyeCortex/Configs/<ModuleName>_Config.json`
- Pending queue: `C:/BrownEyeCortex/Pipelines/<ModuleName>/Pending.csv`
- Archive: `C:/BrownEyeCortex/Pipelines/<ModuleName>/Archive/`
- Bootstrap gatekeeper: `C:/BrownEyeCortex/Bootstraps/<ModuleName>_ClosedLoop_Bootstrap.ps1`

## Template Fields (Pending.csv)
`Tier,ItemName,Source,Destination,PriceFrom,PriceTo,SpreadPct,Notes,UrlFrom,UrlTo`

## Example Module: SSBBW Content Sales
**Config**: `C:/BrownEyeCortex/Configs/SSBBW_Config.json`
- `Enabled`
- `MaxAlertsPerRun`
- `DryRun`
- `PreviewOnly`
- `ArchiveEnabled`

**Pending.csv**: Orders ready for review.
- `Tier` = Priority or customer segment.
- `ItemName` = Product or content package.
- `Source` = Intake channel.
- `Destination` = Fulfillment channel (Discord, email, etc.).

**Bootstrap**: Posts approved orders to Discord or email and archives the row.

## Example Module: Consulting Leads
**Config**: `C:/BrownEyeCortex/Configs/Consulting_Config.json`

**Pending.csv**: Leads awaiting approval.
- `ItemName` = Company or contact.
- `Notes` = Lead qualification summary.

**Bootstrap**: Pushes to Discord/Notion, then archives.

## Example Module: Patreon Primers
**Config**: `C:/BrownEyeCortex/Configs/Patreon_Primers_Config.json`

**Pending.csv**: Decklists pending primer generation.
- `ItemName` = Deck name.
- `Notes` = Link to list, target format.

**Bootstrap**: Triggers primer generation workflow, then archives.

## Implementation Guidance
- Keep bootstrap scripts as the only gatekeepers that post or trigger actions.
- Scanners or intake scripts should only populate `Pending.csv`.
- Use rate limits and preview/dry-run flags to prevent accidental posting.
