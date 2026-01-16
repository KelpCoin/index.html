from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import requests

from cortex.modules.base import CortexModule, ModuleResult


class DeckPricingModule(CortexModule):
    name = "deck_pricing"
    version = "1.0.0"

    def _load_decklist(self, path: Path) -> List[str]:
        cards = []
        if not path.exists():
            return cards
        for line in path.read_text(encoding="utf-8").splitlines():
            cleaned = line.strip()
            if not cleaned or cleaned.startswith("#"):
                continue
            parts = cleaned.split(" ", 1)
            if len(parts) == 2 and parts[0].isdigit():
                cards.append(parts[1])
            else:
                cards.append(cleaned)
        return cards

    def _price_card(self, name: str) -> float:
        response = requests.get(
            "https://api.scryfall.com/cards/named",
            params={"fuzzy": name},
            timeout=20,
        )
        if response.status_code != 200:
            return 0.0
        data = response.json()
        prices = data.get("prices", {})
        return float(prices.get("usd") or 0)

    def run(self) -> ModuleResult:
        deck_path = Path(self.config.get("decklist_path", ""))
        cards = self._load_decklist(deck_path)
        prices = []
        total = 0.0
        for card in cards:
            price = self._price_card(card)
            prices.append({"card": card, "usd": price})
            total += price
        payload = {
            "decklist_path": str(deck_path),
            "cards": prices,
            "total_usd": round(total, 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        output_path = Path(self.config.get("output_json", "deck_pricing.json"))
        output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        summary = f"Deck pricing complete for {len(cards)} cards. Total USD ${round(total, 2)}."
        return ModuleResult(
            name=self.name,
            fingerprint=self.fingerprint(),
            summary=summary,
            payload=payload,
            timestamp=self.timestamp(),
        )
