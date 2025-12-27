from browneye_sim.cards import CardEntry, Deck
from browneye_sim.rules import Game


def make_simple_deck(name: str) -> Deck:
    cards = [CardEntry(name="Basic Land", qty=30), CardEntry(name="Generic Threat", qty=30)]
    return Deck(name=name, commander="Cmdr", cards=cards)


def test_game_completes():
    deck_a = make_simple_deck("A")
    deck_b = make_simple_deck("B")
    game = Game(deck_a, deck_b, starting_life=20, max_turns=5)
    result = game.run()
    assert result.winner in {deck_a.name, deck_b.name}
