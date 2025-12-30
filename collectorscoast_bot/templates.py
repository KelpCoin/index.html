"""Tweet formatting helpers."""
from __future__ import annotations

from .config import settings


def movement_summary(name: str, price_nzd: float, change_pct: float, reason: str) -> str:
    direction = "up" if change_pct >= 0 else "down"
    change_text = f"{change_pct:+.1f}% {direction} to ${price_nzd:.2f} NZD"
    why = reason.capitalize()
    disclaimer = "NZ Market — not financial advice"
    body = f"{name}: {change_text}. {why}."
    hashtags = ["#mtgfinance"]
    if "commander" in reason.lower():
        hashtags.append("#commandermtg")
    hashtags.append("#mtgnz")
    tags_text = " ".join(hashtags)
    return f"{body}\n{tags_text}\n{disclaimer}\n{settings.ticker_url}"


def arbitrage_summary(name: str, price_nzd: float, change_pct: float, reason: str) -> str:
    body = movement_summary(name, price_nzd, change_pct, reason)
    return body.replace("mtgfinance", "mtgfinance arbitrage")
