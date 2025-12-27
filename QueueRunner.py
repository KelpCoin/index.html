"""QueueRunner script with price snapshot caching.

This module computes card spreads and appends price snapshots to a JSONL
file for downstream processing.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Optional

logging.basicConfig(level=logging.INFO)

PRICE_CACHE_PATH = Path(r"C:\\BrownEyeCortex\\Data\\Lake\\Arbitrage\\prices.jsonl")


@dataclass
class CardPrice:
    card: str
    marketplace: str
    buy_price: float
    sell_price: float
    region: str


@dataclass
class SpreadResult:
    card: str
    marketplace: str
    spread: float
    buy_price: float
    sell_price: float
    region: str


class QueueRunner:
    """QueueRunner orchestrates spread computation and price caching."""

    def __init__(self, price_cache_path: Path = PRICE_CACHE_PATH) -> None:
        self.price_cache_path = price_cache_path
        self._ensure_price_cache_path()

    def _ensure_price_cache_path(self) -> None:
        try:
            self.price_cache_path.parent.mkdir(parents=True, exist_ok=True)
        except Exception as exc:  # pragma: no cover - defensive
            logging.exception("Failed to ensure price cache directory: %s", exc)
            raise

    def _append_price_snapshot(self, price: CardPrice) -> None:
        """Append a single price snapshot to the JSONL cache."""
        snapshot = {
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "card": price.card,
            "marketplace": price.marketplace,
            "buy_price": price.buy_price,
            "sell_price": price.sell_price,
            "region": price.region,
        }

        try:
            with self.price_cache_path.open("a", encoding="utf-8", newline="\n") as cache_file:
                cache_file.write(json.dumps(snapshot, separators=(",", ":")))
                cache_file.write("\n")
        except Exception as exc:  # pragma: no cover - defensive
            logging.exception("Failed to append price snapshot: %s", exc)
            raise

    def compute_spreads(self, prices: Iterable[CardPrice]) -> List[SpreadResult]:
        """Compute spreads and cache price snapshots.

        Args:
            prices: Iterable of CardPrice entries for which spreads are computed.

        Returns:
            List of SpreadResult entries.
        """
        results: List[SpreadResult] = []
        for price in prices:
            spread_value = price.sell_price - price.buy_price
            result = SpreadResult(
                card=price.card,
                marketplace=price.marketplace,
                spread=spread_value,
                buy_price=price.buy_price,
                sell_price=price.sell_price,
                region=price.region,
            )
            results.append(result)
            self._append_price_snapshot(price)
        return results

    def run(self, price_feed: Iterable[CardPrice]) -> None:
        """Process a stream of prices, computing spreads along the way."""
        for batch in self._batched(price_feed, batch_size=50):
            spread_results = self.compute_spreads(batch)
            logging.info("Processed %d price entries", len(spread_results))

    @staticmethod
    def _batched(prices: Iterable[CardPrice], batch_size: int) -> Iterable[List[CardPrice]]:
        batch: List[CardPrice] = []
        for price in prices:
            batch.append(price)
            if len(batch) >= batch_size:
                yield batch
                batch = []
        if batch:
            yield batch


def main(price_feed: Optional[Iterable[CardPrice]] = None) -> None:
    # Placeholder price feed. Replace with the real queue-backed feed.
    price_feed = price_feed or [
        CardPrice(card="Sample Card", marketplace="DemoMarket", buy_price=10.0, sell_price=12.5, region="NA"),
        CardPrice(card="Sample Card 2", marketplace="DemoMarket", buy_price=5.0, sell_price=7.0, region="EU"),
    ]

    runner = QueueRunner()
    runner.run(price_feed)


if __name__ == "__main__":
    main()
