"""Batch simulation utilities."""

from __future__ import annotations

import itertools
import json
import os
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Tuple

from .config import SimulationConfig
from .io_formats import save_markdown_report, save_summary_json
from .rules import Game
from .cards import Deck


@dataclass
class MatchupResult:
    deck_a: str
    deck_b: str
    games: int
    wins_a: int
    wins_b: int
    avg_turns: float


@dataclass
class SimulationRun:
    timestamp: str
    config: SimulationConfig
    matchups: List[MatchupResult] = field(default_factory=list)


class Simulator:
    """Run many pairwise simulations and aggregate results."""

    def __init__(self, decks: Dict[str, Deck], config: SimulationConfig) -> None:
        self.decks = decks
        self.config = config

    def run_pairing(self, deck_a: Deck, deck_b: Deck, games: int) -> MatchupResult:
        wins_a = 0
        total_turns = 0
        for _ in range(games):
            game = Game(deck_a, deck_b, starting_life=self.config.starting_life, max_turns=self.config.max_turns)
            result = game.run()
            total_turns += result.turns
            if result.winner == deck_a.name:
                wins_a += 1
        wins_b = games - wins_a
        avg_turns = total_turns / games if games else 0
        return MatchupResult(deck_a=deck_a.name, deck_b=deck_b.name, games=games, wins_a=wins_a, wins_b=wins_b, avg_turns=avg_turns)

    def run_all_pairings(self) -> SimulationRun:
        timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H%M%SZ")
        run = SimulationRun(timestamp=timestamp, config=self.config)

        pairs = itertools.combinations(self.decks.values(), 2)
        for deck_a, deck_b in pairs:
            result = self.run_pairing(deck_a, deck_b, self.config.games_per_pairing)
            run.matchups.append(result)

        self._persist_run(run)
        return run

    def _persist_run(self, run: SimulationRun) -> None:
        directory = os.path.join("runs", run.timestamp)
        os.makedirs(directory, exist_ok=True)
        save_summary_json(run, directory)
        save_markdown_report(run, directory)
