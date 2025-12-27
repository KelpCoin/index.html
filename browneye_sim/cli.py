"""Command-line interface for BrownEye Commander Simulator."""

from __future__ import annotations

import argparse
import json
import os
from typing import Optional

from .config import SimulationConfig, default_config
from .io_formats import (
    load_deck_from_json,
    load_deck_from_text,
    load_registered_decks,
    save_deck,
)
from .simulator import Simulator


def cmd_import_deck(args: argparse.Namespace) -> None:
    if args.json:
        deck = load_deck_from_json(args.json)
    else:
        if not args.name or not args.commander:
            raise SystemExit("--name and --commander required for text imports")
        deck = load_deck_from_text(args.text, args.name, args.commander)
    path = save_deck(deck)
    print(f"Imported deck '{deck.name}' to {path}")


def cmd_list_decks(_: argparse.Namespace) -> None:
    decks = load_registered_decks()
    if not decks:
        print("No decks registered. Use import-deck first.")
        return
    for deck in decks.values():
        print(f"- {deck.name} (Commander: {deck.commander})")


def cmd_simulate(args: argparse.Namespace) -> None:
    decks = load_registered_decks()
    if args.deck_a not in decks or args.deck_b not in decks:
        raise SystemExit("Requested decks not found. Import them first.")
    config = SimulationConfig(games_per_pairing=args.games, starting_life=args.starting_life, max_turns=args.max_turns)
    simulator = Simulator(decks={args.deck_a: decks[args.deck_a], args.deck_b: decks[args.deck_b]}, config=config)
    run = simulator.run_all_pairings()
    print(f"Simulation complete. Results in runs/{run.timestamp}")


def cmd_last_results(_: argparse.Namespace) -> None:
    runs_dir = "runs"
    if not os.path.exists(runs_dir):
        print("No runs yet.")
        return
    entries = sorted(os.listdir(runs_dir), reverse=True)
    if not entries:
        print("No runs yet.")
        return
    latest = entries[0]
    summary_path = os.path.join(runs_dir, latest, "summary.json")
    report_path = os.path.join(runs_dir, latest, "report.md")
    if os.path.exists(summary_path):
        with open(summary_path, "r", encoding="utf-8") as f:
            summary = json.load(f)
        print(json.dumps(summary, indent=2))
    if os.path.exists(report_path):
        print("\nMarkdown report:\n")
        with open(report_path, "r", encoding="utf-8") as f:
            print(f.read())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="BrownEye Commander Simulator")
    sub = parser.add_subparsers(dest="command")

    imp = sub.add_parser("import-deck", help="Import a deck from JSON or text")
    group = imp.add_mutually_exclusive_group(required=True)
    group.add_argument("--json", help="Path to deck JSON file")
    group.add_argument("--text", help="Path to deck text file")
    imp.add_argument("--name", help="Deck name (required for text imports)")
    imp.add_argument("--commander", help="Commander name (required for text imports)")
    imp.set_defaults(func=cmd_import_deck)

    lst = sub.add_parser("list-decks", help="List registered decks")
    lst.set_defaults(func=cmd_list_decks)

    sim = sub.add_parser("simulate", help="Run simulations between two decks")
    sim.add_argument("--deck-a", required=True)
    sim.add_argument("--deck-b", required=True)
    sim.add_argument("--games", type=int, default=10)
    sim.add_argument("--starting-life", type=int, default=40)
    sim.add_argument("--max-turns", type=int, default=20)
    sim.set_defaults(func=cmd_simulate)

    last = sub.add_parser("last-results", help="Show most recent results")
    last.set_defaults(func=cmd_last_results)

    return parser


def main(argv: Optional[list[str]] = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not hasattr(args, "func"):
        parser.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()
