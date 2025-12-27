# BrownEye Commander Simulator

BrownEye Commander Simulator is a fully offline, Python 3.11+ CLI tool for running simplified Commander/EDH matchup simulations. It parses Commander decklists, plays many games using an internal rules engine and heuristic AI, and emits JSON and Markdown reports to support data-driven deck primers.

## Features
- Import decks from JSON or simple text list formats.
- Simplified but extensible Commander rules engine with scripted cards and abilities.
- Deterministic heuristic AI for reproducible simulations.
- Batch simulator with JSON + Markdown outputs and run history.
- Modular architecture designed for future expansion (more cards, rules depth, multiplayer).

## Installation
1. Ensure Python 3.11+ is installed.
2. Clone this repository and install dependencies:
   ```bash
   pip install -e .
   ```

## Usage
### Import a deck
```bash
python -m browneye_sim.cli import-deck browneye_sim/examples/example_decks/atraxa.json
```

### List registered decks
```bash
python -m browneye_sim.cli list-decks
```

### Run simulations
```bash
python -m browneye_sim.cli simulate --deck-a "Atraxa Superfriends" --deck-b "Isshin Tokens" --games 20
```
This writes outputs under `runs/<timestamp>/summary.json` and `report.md`.

### Show last results
```bash
python -m browneye_sim.cli last-results
```

## Deck formats
- **JSON**: includes deck name, commander, and card entries with quantities.
- **Text**: one card per line, with optional `4x` prefixes. Provide deck name and commander through CLI flags when importing text.

## Tests
Run the minimal test suite:
```bash
python -m pytest
```

## Packaging into an .exe on Windows with PyInstaller
Example command:
```bash
pyinstaller --onefile -m browneye_sim.cli
```

## Project structure
```
browneye_sim/
  cards.py         # card + deck models and scripted card registry
  rules.py         # simplified rules engine and game loop
  ai.py            # heuristic AI policies
  simulator.py     # batch game runner and stats aggregator
  io_formats.py    # deck import/export and report generation
  cli.py           # command-line interface
  config.py        # default simulation configuration
  examples/
    example_decks/
      atraxa.json
      isshin.json
```

## Notes
- The rules engine is intentionally simplified for speed and clarity. It models Commander basics (40 life, zones, turn structure, combat, simple triggers) and is structured to allow deeper rules to be added later.
- The AI is deterministic and focuses on consistent play patterns: play lands, ramp/draw early, deploy threats, attack when favorable, and remove high-value targets.
