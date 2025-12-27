"""Deck import/export and report generation."""

from __future__ import annotations

import json
import os
from dataclasses import asdict
from typing import Dict, List, TYPE_CHECKING

from .cards import CardEntry, Deck

if TYPE_CHECKING:  # pragma: no cover
    from .simulator import MatchupResult, SimulationRun


def load_deck_from_json(path: str) -> Deck:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    cards = [CardEntry(**entry) for entry in data.get("cards", [])]
    return Deck(name=data["name"], commander=data.get("commander", ""), cards=cards)


def load_deck_from_text(path: str, name: str, commander: str) -> Deck:
    cards: List[CardEntry] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            raw = line.strip()
            if not raw:
                continue
            qty = 1
            if raw[0].isdigit() and "x" in raw:
                qty_part, card_name = raw.split("x", 1)
                qty = int(qty_part)
                raw = card_name.strip()
            cards.append(CardEntry(name=raw, qty=qty))
    return Deck(name=name, commander=commander, cards=cards)


def save_deck(deck: Deck, directory: str = "decks") -> str:
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, f"{deck.name.replace(' ', '_')}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"name": deck.name, "commander": deck.commander, "cards": [asdict(c) for c in deck.cards]}, f, indent=2)
    return path


def load_registered_decks(directory: str = "decks") -> Dict[str, Deck]:
    decks: Dict[str, Deck] = {}
    if not os.path.exists(directory):
        return decks
    for filename in os.listdir(directory):
        if filename.endswith(".json"):
            deck = load_deck_from_json(os.path.join(directory, filename))
            decks[deck.name] = deck
    return decks


def save_summary_json(run: "SimulationRun", directory: str) -> str:
    path = os.path.join(directory, "summary.json")
    payload = {
        "timestamp": run.timestamp,
        "config": asdict(run.config),
        "matchups": [asdict(m) for m in run.matchups],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    return path


def save_markdown_report(run: "SimulationRun", directory: str) -> str:
    path = os.path.join(directory, "report.md")
    lines: List[str] = []
    lines.append(f"# BrownEye Commander Simulator Report ({run.timestamp})\n")
    for match in run.matchups:
        lines.append(f"## {match.deck_a} vs {match.deck_b} ({match.games} games)\n")
        win_rate_a = match.wins_a / match.games * 100 if match.games else 0
        win_rate_b = match.wins_b / match.games * 100 if match.games else 0
        lines.append(f"- Win rate: {win_rate_a:.1f}% vs {win_rate_b:.1f}%")
        lines.append(f"- Average game length: {match.avg_turns:.1f} turns")
        lines.append("- Summary: {0} favors acceleration and closing with large threats.".format(match.deck_a))
        lines.append("- Notes: {0} may rely on removal to survive early turns.".format(match.deck_b))
        lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return path
