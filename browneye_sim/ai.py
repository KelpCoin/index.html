"""Deterministic heuristic AI utilities."""

from __future__ import annotations

from typing import List

from .cards import Card


class HeuristicAI:
    """Simple deterministic policies for card priorities."""

    def choose_opening_hand_to_keep(self, hand: List[Card]) -> List[Card]:
        # For now, always keep initial 7.
        return hand

    def choose_attackers(self, creatures: List[Card]) -> List[Card]:
        # Attack with everything that has power > 0
        return [c for c in creatures if c.power > 0]
