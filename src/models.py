from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class Settings:
    discord_webhook_url: str
    currency_base: str
    min_profit_absolute: float
    min_profit_percent: float
    max_buy_price: float
    max_results_per_run: int
    enable_vendor_tcgplayer: bool
    enable_vendor_cardmarket: bool
    enable_vendor_cardkingdom: bool
    enable_vendor_trademe: bool
    patreon_link: str
    brand_tag: str


@dataclass
class CardEntry:
    name: str
    set_code: Optional[str] = None


@dataclass
class ArbOpportunity:
    card_name: str
    set_code: Optional[str]
    best_buy_vendor: str
    best_buy_price: float
    best_sell_vendor: str
    best_sell_price: float
    profit_absolute: float
    profit_percent: float
    timestamp: str
