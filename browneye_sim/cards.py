"""Card and deck models plus a simple scripted card registry."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Callable, Dict, List, Optional


class CardType(Enum):
    LAND = auto()
    CREATURE = auto()
    SORCERY = auto()
    INSTANT = auto()
    ENCHANTMENT = auto()
    ARTIFACT = auto()
    PLANESWALKER = auto()


@dataclass
class Card:
    """Simplified representation of a Magic card."""

    name: str
    card_type: CardType
    mana_cost: int = 0
    power: int = 0
    toughness: int = 0
    tags: List[str] = field(default_factory=list)
    rules_text: str = ""
    scripted_ability: Optional[Callable] = None

    def is_land(self) -> bool:
        return self.card_type == CardType.LAND

    def is_creature(self) -> bool:
        return self.card_type == CardType.CREATURE


@dataclass
class CardEntry:
    name: str
    qty: int = 1


@dataclass
class Deck:
    name: str
    commander: str
    cards: List[CardEntry]

    def all_cards(self) -> List[str]:
        names: List[str] = []
        for entry in self.cards:
            names.extend([entry.name] * entry.qty)
        return names


# Scripted card registry ----------------------------------------------------

class CardRegistry:
    """Registry of scripted cards that the engine knows how to execute."""

    def __init__(self) -> None:
        self._cards: Dict[str, Card] = {}
        self._bootstrap()

    def _add(self, card: Card) -> None:
        self._cards[card.name.lower()] = card

    def get(self, name: str) -> Card:
        key = name.lower()
        if key not in self._cards:
            return Card(name=name, card_type=CardType.CREATURE, mana_cost=3, power=2, toughness=2, tags=["vanilla"], rules_text="Default placeholder creature")
        return self._cards[key]

    def _bootstrap(self) -> None:
        self._add(
            Card(
                name="Sol Ring",
                card_type=CardType.ARTIFACT,
                mana_cost=1,
                tags=["ramp"],
                rules_text="Tap: Add {C}{C}.",
            )
        )
        self._add(
            Card(
                name="Mana Crypt",
                card_type=CardType.ARTIFACT,
                mana_cost=0,
                tags=["ramp"],
                rules_text="Tap: Add {C}{C}.",  # ignore damage drawback
            )
        )
        self._add(
            Card(
                name="Cultivate",
                card_type=CardType.SORCERY,
                mana_cost=3,
                tags=["ramp"],
                rules_text="Search for basic lands, one to battlefield tapped and one to hand.",
            )
        )
        self._add(
            Card(
                name="Solemn Simulacrum",
                card_type=CardType.CREATURE,
                mana_cost=4,
                power=2,
                toughness=2,
                tags=["ramp", "value"],
                rules_text="ETB: search for basic land tapped. When dies: draw a card.",
            )
        )
        self._add(
            Card(
                name="Rhystic Study",
                card_type=CardType.ENCHANTMENT,
                mana_cost=3,
                tags=["draw"],
                rules_text="At upkeep, draw a card (simplified).",
            )
        )
        self._add(
            Card(
                name="Generic Threat",
                card_type=CardType.CREATURE,
                mana_cost=5,
                power=5,
                toughness=5,
                tags=["threat"],
                rules_text="Big creature to close games.",
            )
        )
        self._add(
            Card(
                name="Lightning Bolt",
                card_type=CardType.INSTANT,
                mana_cost=1,
                tags=["removal"],
                rules_text="Deal 3 damage to target creature or player.",
            )
        )
        self._add(
            Card(
                name="Path to Exile",
                card_type=CardType.INSTANT,
                mana_cost=1,
                tags=["removal"],
                rules_text="Exile target creature. (opponent gains land)",
            )
        )
        self._add(
            Card(
                name="Arcane Signet",
                card_type=CardType.ARTIFACT,
                mana_cost=2,
                tags=["ramp"],
                rules_text="Tap: Add one mana of any color.",
            )
        )
        self._add(
            Card(
                name="Basic Land",
                card_type=CardType.LAND,
                mana_cost=0,
                tags=["land"],
                rules_text="Tap: Add one mana of any color.",
            )
        )


CARD_REGISTRY = CardRegistry()
