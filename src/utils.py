from __future__ import annotations

import json
import logging
import os
from datetime import datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Dict, List

from dotenv import load_dotenv

from models import CardEntry, Settings

BASE_DIR = Path(__file__).resolve().parent.parent
LOG_PATH = BASE_DIR / "logs" / "arbiter.log"
CONFIG_PATH = BASE_DIR / "config" / "settings.env"
CARDS_PATH = BASE_DIR / "data" / "input_cards.txt"
CACHE_PATH = BASE_DIR / "data" / "cache" / "vendor_cache.json"
ARTIFACTS_DIR = BASE_DIR / "artifacts" / "daily"


def ensure_directories() -> None:
    for path in [LOG_PATH.parent, CACHE_PATH.parent, ARTIFACTS_DIR]:
        path.mkdir(parents=True, exist_ok=True)


def get_logger() -> logging.Logger:
    ensure_directories()
    logger = logging.getLogger("arbiter")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    handler = RotatingFileHandler(LOG_PATH, maxBytes=512_000, backupCount=3)
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    console = logging.StreamHandler()
    console.setFormatter(formatter)
    logger.addHandler(console)
    return logger


def _str_to_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def load_settings() -> Settings:
    ensure_directories()
    load_dotenv(dotenv_path=CONFIG_PATH)
    return Settings(
        discord_webhook_url=os.getenv("DISCORD_WEBHOOK_URL", ""),
        currency_base=os.getenv("CURRENCY_BASE", "USD"),
        min_profit_absolute=float(os.getenv("MIN_PROFIT_ABSOLUTE", "3.0")),
        min_profit_percent=float(os.getenv("MIN_PROFIT_PERCENT", "20.0")),
        max_buy_price=float(os.getenv("MAX_BUY_PRICE", "100.0")),
        max_results_per_run=int(os.getenv("MAX_RESULTS_PER_RUN", "25")),
        enable_vendor_tcgplayer=_str_to_bool(os.getenv("ENABLE_VENDOR_TCGPLAYER", "true")),
        enable_vendor_cardmarket=_str_to_bool(os.getenv("ENABLE_VENDOR_CARDMARKET", "true")),
        enable_vendor_cardkingdom=_str_to_bool(os.getenv("ENABLE_VENDOR_CARDKINGDOM", "true")),
        enable_vendor_trademe=_str_to_bool(os.getenv("ENABLE_VENDOR_TRADEME", "false")),
        patreon_link=os.getenv("PATREON_LINK", ""),
        brand_tag=os.getenv("BRAND_TAG", "[HAPPYHOMARID MTG ARB]"),
    )


def load_cards() -> List[CardEntry]:
    ensure_directories()
    cards: List[CardEntry] = []
    if not CARDS_PATH.exists():
        return cards
    with CARDS_PATH.open("r", encoding="ascii", errors="ignore") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "[" in stripped and stripped.endswith("]"):
                name_part, set_part = stripped.rsplit("[", 1)
                name = name_part.strip()
                set_code = set_part[:-1].strip().upper() or None
            else:
                name = stripped
                set_code = None
            if not name:
                continue
            cards.append(CardEntry(name=name, set_code=set_code))
    return cards


def read_cache() -> Dict[str, Dict[str, str]]:
    ensure_directories()
    if not CACHE_PATH.exists():
        return {}
    try:
        with CACHE_PATH.open("r", encoding="ascii") as handle:
            return json.load(handle)
    except Exception:
        return {}


def write_cache(cache: Dict[str, Dict[str, str]]) -> None:
    ensure_directories()
    try:
        with CACHE_PATH.open("w", encoding="ascii") as handle:
            json.dump(cache, handle, indent=2)
    except Exception:
        # logging here could create recursion; fail silently
        pass


def iso_timestamp() -> str:
    return datetime.utcnow().isoformat()
