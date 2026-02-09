# BrownEye Build Map

## Modules
- **Loop Orchestrator**: `scripts/run_cycle.sh`
- **Cinema Slice 1** (doorway): `cinema/doorway.html`
- **Cinema Slice 2** (billboard renderer): `cinema/billboard.html`, `cinema/notion_stub.json`
- **Game Slice 1** (core loop skeleton): `game/index.html`, `game/game.js`
- **Memory + Ledger**:
  - `D:\\BrownEyeCortexData\\MemoryVault\\CANON.json`
  - `D:\\BrownEyeCortexData\\MemoryVault\\WORKLOG.jsonl`

## Artifact Paths (priority)
1. `D:\\BrownEye\\BROWNEYE_ARTIFACTS`
2. `C:\\BrownEyeCortex\\_artifacts` (fallback)

## Verifiers
- `bash scripts/run_cycle.sh verify`
- `bash scripts/run_cycle.sh cinema`
- `bash scripts/run_cycle.sh game`

## Kill Switches
- `BROWNEYE_DISABLE_PUBLIC=1` (default) blocks external dispatch.
- `BROWNEYE_FORCE_FALLBACK=1` forces fallback artifact root.
- Hard silo checks reject mixed `MTG|HappyHomarid` with `adult|Amplissa` tokens.
