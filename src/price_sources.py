from __future__ import annotations

import random
import time
from abc import ABC, abstractmethod
from typing import Optional

from models import CardEntry
from utils import read_cache, write_cache

CACHE_TTL_SECONDS = 6 * 60 * 60


class PriceSource(ABC):
    name: str

    @abstractmethod
    def get_price(self, card: CardEntry) -> Optional[float]:
        raise NotImplementedError


class _CachedPriceSource(PriceSource):
    def __init__(self, name: str) -> None:
        self.name = name

    def get_price(self, card: CardEntry) -> Optional[float]:
        cache = read_cache()
        cache_key = f"{self.name}|{card.name}|{card.set_code or 'ANY'}"
        cached = cache.get(cache_key)
        now = time.time()
        if cached:
            try:
                timestamp = float(cached.get("timestamp", 0))
                if now - timestamp < CACHE_TTL_SECONDS:
                    return float(cached.get("price"))
            except Exception:
                pass
        try:
            price = self.fetch_price(card)
        except Exception:
            price = None
        if price is not None:
            cache[cache_key] = {"price": price, "timestamp": str(now)}
            write_cache(cache)
        return price

    @abstractmethod
    def fetch_price(self, card: CardEntry) -> Optional[float]:
        raise NotImplementedError

    @staticmethod
    def _simulate_price(card: CardEntry, floor: float, ceiling: float) -> Optional[float]:
        seed_value = f"{card.name}-{card.set_code or 'any'}-{floor}-{ceiling}"
        random.seed(seed_value)
        if random.random() < 0.15:
            return None
        price = floor + (random.random() * (ceiling - floor))
        return round(price, 2)


class TCGPlayerSource(_CachedPriceSource):
    def __init__(self) -> None:
        super().__init__("TCGPlayer")

    def fetch_price(self, card: CardEntry) -> Optional[float]:
        # TODO: Replace with real TCGplayer API integration when credentials are available.
        return self._simulate_price(card, 5.0, 90.0)


class CardmarketSource(_CachedPriceSource):
    def __init__(self) -> None:
        super().__init__("Cardmarket")

    def fetch_price(self, card: CardEntry) -> Optional[float]:
        # TODO: Replace with real Cardmarket API integration when credentials are available.
        return self._simulate_price(card, 4.5, 85.0)


class CardKingdomSource(_CachedPriceSource):
    def __init__(self) -> None:
        super().__init__("CardKingdom")

    def fetch_price(self, card: CardEntry) -> Optional[float]:
        # TODO: Replace with real Card Kingdom scraping/API when available.
        return self._simulate_price(card, 6.0, 95.0)


class TradeMeSource(_CachedPriceSource):
    def __init__(self) -> None:
        super().__init__("TradeMe")

    def fetch_price(self, card: CardEntry) -> Optional[float]:
        # Placeholder stub. TradeMe integration can be added later.
        return self._simulate_price(card, 7.0, 80.0)
