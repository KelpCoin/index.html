from __future__ import annotations

import json
from datetime import datetime
from typing import List

from arbitrage_engine import find_arbitrage_opportunities
from discord_notifier import send_discord_summary
from models import ArbOpportunity
from price_sources import CardKingdomSource, CardmarketSource, TCGPlayerSource, TradeMeSource
from utils import ARTIFACTS_DIR, ensure_directories, get_logger, load_cards, load_settings

logger = get_logger()


def _enabled_sources(settings) -> List:
    sources = []
    if settings.enable_vendor_tcgplayer:
        sources.append(TCGPlayerSource())
    if settings.enable_vendor_cardmarket:
        sources.append(CardmarketSource())
    if settings.enable_vendor_cardkingdom:
        sources.append(CardKingdomSource())
    if settings.enable_vendor_trademe:
        sources.append(TradeMeSource())
    return sources


def _write_artifact(opportunities: List[ArbOpportunity], settings) -> Path:
    ensure_directories()
    date_str = datetime.utcnow().strftime("%Y-%m-%d")
    target_path = ARTIFACTS_DIR / f"{date_str}_arbitrage.json"
    payload = {
        "brand": settings.brand_tag.replace("[", "").replace("]", ""),
        "run_timestamp": datetime.utcnow().isoformat(),
        "settings": {
            "currency_base": settings.currency_base,
            "min_profit_absolute": settings.min_profit_absolute,
            "min_profit_percent": settings.min_profit_percent,
            "max_buy_price": settings.max_buy_price,
            "max_results_per_run": settings.max_results_per_run,
            "vendors": {
                "tcgplayer": settings.enable_vendor_tcgplayer,
                "cardmarket": settings.enable_vendor_cardmarket,
                "cardkingdom": settings.enable_vendor_cardkingdom,
                "trademe": settings.enable_vendor_trademe,
            },
        },
        "count": len(opportunities),
        "opportunities": [op.__dict__ for op in opportunities],
    }
    with target_path.open("w", encoding="ascii") as handle:
        json.dump(payload, handle, indent=2)
    logger.info("Wrote artifact to %s", target_path)
    return target_path


def main() -> None:
    ensure_directories()
    logger.info("\n=== MTG Arbitrage run starting ===")
    settings = load_settings()
    cards = load_cards()
    if not cards:
        logger.warning("No cards to process. Check data/input_cards.txt")
    sources = _enabled_sources(settings)
    if not sources:
        logger.warning("No price sources enabled. Enable at least two vendors in settings.env")
    opportunities = find_arbitrage_opportunities(cards, sources, settings)
    artifact_path = _write_artifact(opportunities, settings)
    send_discord_summary(opportunities, settings)
    logger.info(
        "Run complete. Cards: %s | Opportunities: %s | Artifact: %s",
        len(cards),
        len(opportunities),
        artifact_path,
    )
    print(
        f"MTG Arbiter finished: {len(cards)} cards processed, {len(opportunities)} opportunities found."
    )


if __name__ == "__main__":
    main()
