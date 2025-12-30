"""Fetch and normalize feed data from a JSON endpoint or local file."""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.request import urlopen

from .logger import logger


@dataclass
class Movement:
    name: str
    price_nzd: float
    change_pct: float
    reason: str
    category: str
    uri: str | None = None


def _load_from_url(url: str) -> dict:
    logger.debug("Fetching feed from %s", url)
    with urlopen(url) as response:  # noqa: S310 - trusted feed URL
        return json.loads(response.read())


def _load_from_file(path: Path) -> dict:
    logger.debug("Loading feed from file %s", path)
    with path.open() as f:
        return json.load(f)


def load_feed(feed_url: str) -> Iterable[Movement]:
    """Load feed data from a URL or local file path."""
    if feed_url.startswith("http"):
        raw = _load_from_url(feed_url)
    else:
        raw = _load_from_file(Path(feed_url))

    movements = []
    for item in raw.get("movements", []):
        try:
            movements.append(
                Movement(
                    name=item["name"],
                    price_nzd=float(item["price_nzd"]),
                    change_pct=float(item["change_pct"]),
                    reason=item.get("reason", "movement"),
                    category=item.get("category", "mover"),
                    uri=item.get("uri"),
                )
            )
        except (KeyError, TypeError, ValueError) as exc:  # pragma: no cover - defensive
            logger.warning("Skipping invalid feed item %s: %s", item, exc)
    return movements
