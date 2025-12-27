from browneye_sim.cards import CardEntry, Deck
from browneye_sim.config import SimulationConfig
from browneye_sim.simulator import Simulator


def make_deck(name: str) -> Deck:
    return Deck(name=name, commander="Cmdr", cards=[CardEntry(name="Basic Land", qty=35), CardEntry(name="Generic Threat", qty=25)])


def test_simulation_summary(tmp_path, monkeypatch):
    deck_a = make_deck("DeckA")
    deck_b = make_deck("DeckB")
    config = SimulationConfig(games_per_pairing=2, starting_life=20, max_turns=3)
    sim = Simulator({deck_a.name: deck_a, deck_b.name: deck_b}, config=config)
    run = sim.run_all_pairings()
    assert run.matchups[0].games == 2
