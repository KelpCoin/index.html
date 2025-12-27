import json
from pathlib import Path
from typing import Dict, Tuple

from change_journal import ChangeJournal
from file_utils import SafeFileManager
from governance import GovernanceGate
from rollback_engine import RollbackEngine


class PrimerPipeline:
    def __init__(self, gate: GovernanceGate, journal: ChangeJournal, rollback: RollbackEngine):
        self.gate = gate
        self.journal = journal
        self.manager = SafeFileManager(gate, journal, rollback)

    def _load_deck(self, deck_path: Path) -> Dict:
        self.gate.guard("non_destructive_read", deck_path)
        with deck_path.open("r", encoding="utf-8") as handle:
            return json.load(handle) if deck_path.suffix == ".json" else {"raw_text": handle.read(), "deck_name": deck_path.stem}

    def _render_markdown(self, deck: Dict) -> Tuple[str, Dict]:
        deck_name = deck.get("deck_name", "Unnamed Deck")
        author = deck.get("author", "Unknown")
        lines = [f"# {deck_name}", "", f"Author: {author}", "", "## Strategy", deck.get("strategy", "No strategy provided."), ""]
        key_cards = deck.get("key_cards", [])
        if key_cards:
            lines.append("## Key Cards")
            lines.extend([f"- {card}" for card in key_cards])
            lines.append("")
        weaknesses = deck.get("weaknesses", [])
        if weaknesses:
            lines.append("## Known Weaknesses")
            lines.extend([f"- {weakness}" for weakness in weaknesses])
            lines.append("")
        gameplan = deck.get("gameplan", [])
        if gameplan:
            lines.append("## Gameplan")
            lines.extend([f"1. {step}" for step in gameplan])
            lines.append("")
        metadata = {"deck_name": deck_name, "author": author}
        return "\n".join(lines) + "\n", metadata

    def generate(self, deck_path: Path) -> Tuple[str, Dict]:
        deck = self._load_deck(deck_path)
        markdown, metadata = self._render_markdown(deck)
        description = f"Generated primer content for {metadata['deck_name']}"
        self.journal.log_change("primer_generate", deck_path, description, metadata)
        return markdown, metadata
