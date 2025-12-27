from browneye_sim.io_formats import load_deck_from_json, load_deck_from_text, save_deck
from browneye_sim.cards import Deck
import os

def test_load_and_save_json(tmp_path):
    sample = tmp_path / "deck.json"
    sample.write_text('{"name": "Test", "commander": "Cmdr", "cards": [{"name": "Sol Ring", "qty": 1}]}')
    deck = load_deck_from_json(str(sample))
    assert deck.name == "Test"
    path = save_deck(deck, directory=tmp_path)
    assert os.path.exists(path)


def test_load_from_text(tmp_path):
    sample = tmp_path / "deck.txt"
    sample.write_text("4x Basic Land\nSol Ring\n")
    deck = load_deck_from_text(str(sample), name="Text Deck", commander="Cmdr")
    assert deck.cards[0].qty == 4
