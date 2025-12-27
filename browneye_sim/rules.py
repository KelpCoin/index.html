"""Simplified rules engine and game loop for BrownEye Commander Simulator."""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .cards import CARD_REGISTRY, Card, CardType, Deck


@dataclass
class Permanent:
    card: Card
    tapped: bool = False


@dataclass
class PlayerState:
    deck: Deck
    life: int
    library: List[Card]
    hand: List[Card] = field(default_factory=list)
    battlefield: List[Permanent] = field(default_factory=list)
    graveyard: List[Card] = field(default_factory=list)
    exile: List[Card] = field(default_factory=list)
    mana_pool: int = 0
    lands_played_this_turn: int = 0

    def draw(self, n: int = 1) -> None:
        for _ in range(n):
            if not self.library:
                return
            self.hand.append(self.library.pop())

    def shuffle(self) -> None:
        random.shuffle(self.library)

    def untap_all(self) -> None:
        for perm in self.battlefield:
            perm.tapped = False
        self.mana_pool = 0
        self.lands_played_this_turn = 0

    def add_mana(self, amount: int) -> None:
        self.mana_pool += amount

    def spend_mana(self, cost: int) -> bool:
        if self.mana_pool >= cost:
            self.mana_pool -= cost
            return True
        return False

    def play_land(self) -> bool:
        for idx, card in enumerate(self.hand):
            if card.is_land() and self.lands_played_this_turn == 0:
                self.hand.pop(idx)
                self.battlefield.append(Permanent(card=card, tapped=False))
                self.lands_played_this_turn += 1
                return True
        return False


@dataclass
class GameResult:
    turns: int
    winner: str


@dataclass
class GameState:
    players: Dict[str, PlayerState]
    active_player: str
    non_active_player: str
    turn_number: int = 1

    def switch_active_player(self) -> None:
        self.active_player, self.non_active_player = self.non_active_player, self.active_player
        self.turn_number += 1


class Game:
    """Single-game runner that executes a simplified Commander rules loop."""

    def __init__(self, deck_a: Deck, deck_b: Deck, starting_life: int = 40, max_turns: int = 20, rng: Optional[random.Random] = None):
        self.rng = rng or random.Random()
        player_a = PlayerState(deck=deck_a, life=starting_life, library=self._build_library(deck_a))
        player_b = PlayerState(deck=deck_b, life=starting_life, library=self._build_library(deck_b))
        self.state = GameState(players={deck_a.name: player_a, deck_b.name: player_b}, active_player=deck_a.name, non_active_player=deck_b.name)
        self.max_turns = max_turns

    def _build_library(self, deck: Deck) -> List[Card]:
        library = [CARD_REGISTRY.get(name) for name in deck.all_cards()]
        self.rng.shuffle(library)
        return library

    def _initial_draw(self, player: PlayerState, size: int) -> None:
        player.shuffle()
        player.draw(size)

    def run(self) -> GameResult:
        # initial draws
        for player in self.state.players.values():
            self._initial_draw(player, 7)

        while self.state.turn_number <= self.max_turns:
            if self._turn():
                break
        else:
            # max turns reached
            return self._decide_winner_by_life()

        return self._determine_winner()

    def _turn(self) -> bool:
        active = self.state.players[self.state.active_player]
        opponent = self.state.players[self.state.non_active_player]

        active.untap_all()
        active.draw()

        # Mana from lands and rocks: untap phase adds nothing, main phase will tap as needed.
        active.play_land()
        # Auto-tap lands for available mana equal to untapped land count + ramp rocks
        available_lands = sum(1 for perm in active.battlefield if perm.card.is_land() and not perm.tapped)
        rocks = sum(1 for perm in active.battlefield if "ramp" in perm.card.tags and not perm.tapped)
        active.add_mana(available_lands + rocks)
        for perm in active.battlefield:
            if (perm.card.is_land() or "ramp" in perm.card.tags) and not perm.tapped:
                perm.tapped = True

        self._cast_spells(active, opponent)
        self._combat(active, opponent)
        self._end_step(active)

        # Check win conditions
        if opponent.life <= 0 or not opponent.library:
            return True
        if active.life <= 0 or not active.library:
            return True

        self.state.switch_active_player()
        return False

    def _cast_spells(self, active: PlayerState, opponent: PlayerState) -> None:
        # simple casting priority: ramp -> draw -> removal -> threat
        priorities = ["ramp", "draw", "removal", "threat"]
        for tag in priorities:
            playable_indices = [i for i, card in enumerate(active.hand) if tag in card.tags and active.mana_pool >= card.mana_cost]
            if playable_indices:
                idx = playable_indices[0]
                card = active.hand.pop(idx)
                if not active.spend_mana(card.mana_cost):
                    active.hand.insert(idx, card)
                    continue
                # resolve effect
                if tag == "ramp":
                    self._resolve_ramp(card, active)
                elif tag == "draw":
                    active.draw(1)
                elif tag == "removal":
                    self._resolve_removal(card, opponent)
                elif tag == "threat":
                    active.battlefield.append(Permanent(card=card, tapped=False))
                else:
                    active.graveyard.append(card)
                active.graveyard.append(card)

    def _resolve_ramp(self, card: Card, player: PlayerState) -> None:
        if card.card_type == CardType.SORCERY or card.card_type == CardType.CREATURE:
            # add a basic land to battlefield tapped and one to hand if Cultivate-like
            player.battlefield.append(Permanent(card=CARD_REGISTRY.get("Basic Land"), tapped=True))
            if card.name == "Cultivate":
                player.hand.append(CARD_REGISTRY.get("Basic Land"))
        elif card.card_type == CardType.ARTIFACT:
            player.battlefield.append(Permanent(card=card, tapped=False))
        else:
            player.graveyard.append(card)

    def _resolve_removal(self, card: Card, opponent: PlayerState) -> None:
        # remove highest power creature
        creatures = [perm for perm in opponent.battlefield if perm.card.is_creature()]
        if creatures:
            target = max(creatures, key=lambda p: p.card.power)
            opponent.battlefield.remove(target)
            opponent.graveyard.append(target.card)
            if card.name == "Lightning Bolt":
                opponent.life -= 3
            elif card.name == "Path to Exile":
                opponent.battlefield.append(Permanent(card=CARD_REGISTRY.get("Basic Land"), tapped=True))

    def _combat(self, active: PlayerState, opponent: PlayerState) -> None:
        attackers = [perm for perm in active.battlefield if perm.card.is_creature() and not perm.tapped]
        blockers = [perm for perm in opponent.battlefield if perm.card.is_creature() and not perm.tapped]
        if not attackers:
            return

        if not blockers:
            damage = sum(creature.card.power for creature in attackers)
            opponent.life -= damage
            for creature in attackers:
                creature.tapped = True
            return

        # simplistic blocking: block highest power attacker first
        attackers.sort(key=lambda p: p.card.power, reverse=True)
        blockers.sort(key=lambda p: p.card.toughness, reverse=True)
        while attackers and blockers:
            attacker = attackers.pop(0)
            blocker = blockers.pop(0)
            if attacker.card.power >= blocker.card.toughness:
                opponent.graveyard.append(blocker.card)
            if blocker.card.power >= attacker.card.toughness:
                active.graveyard.append(attacker.card)
            attacker.tapped = True

        # any remaining attackers hit face
        if attackers:
            opponent.life -= sum(creature.card.power for creature in attackers)
            for creature in attackers:
                creature.tapped = True

    def _end_step(self, active: PlayerState) -> None:
        # upkeep-like triggers
        for perm in active.battlefield:
            if perm.card.name == "Rhystic Study":
                active.draw(1)

    def _decide_winner_by_life(self) -> GameResult:
        a_state = self.state.players[self.state.active_player]
        b_state = self.state.players[self.state.non_active_player]
        if a_state.life == b_state.life:
            winner = self.state.active_player
        else:
            winner = self.state.active_player if a_state.life > b_state.life else self.state.non_active_player
        return GameResult(turns=self.state.turn_number, winner=winner)

    def _determine_winner(self) -> GameResult:
        a_state = self.state.players[self.state.active_player]
        b_state = self.state.players[self.state.non_active_player]
        if a_state.life <= 0:
            winner = self.state.non_active_player
        elif b_state.life <= 0:
            winner = self.state.active_player
        elif not a_state.library:
            winner = self.state.non_active_player
        elif not b_state.library:
            winner = self.state.active_player
        else:
            winner = self.state.active_player
        return GameResult(turns=self.state.turn_number, winner=winner)
