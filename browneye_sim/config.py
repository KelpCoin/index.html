"""Default simulation configuration."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class SimulationConfig:
    games_per_pairing: int = 10
    starting_life: int = 40
    max_turns: int = 20
    mulligan_hand_size: int = 7
    allow_partial_mulligan: bool = True


def default_config() -> SimulationConfig:
    """Return a default simulation configuration."""
    return SimulationConfig()
