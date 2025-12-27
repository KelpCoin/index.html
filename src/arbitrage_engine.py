from __future__ import annotations

from typing import List

from models import ArbOpportunity, CardEntry, Settings
from utils import iso_timestamp, get_logger

logger = get_logger()


def find_arbitrage_opportunities(
    card_entries: List[CardEntry],
    price_sources: List,
    settings: Settings,
) -> List[ArbOpportunity]:
    opportunities: List[ArbOpportunity] = []
    logger.info("Starting arbitrage scan for %s cards", len(card_entries))
    for card in card_entries:
        prices = []
        for source in price_sources:
            try:
                price = source.get_price(card)
                if price is not None:
                    prices.append((source.name, price))
            except Exception as exc:
                logger.error("Error fetching price for %s from %s: %s", card.name, source.name, exc)
        if len(prices) < 2:
            logger.info("Skipping %s due to insufficient price data", card.name)
            continue
        best_buy_vendor, best_buy_price = min(prices, key=lambda item: item[1])
        best_sell_vendor, best_sell_price = max(prices, key=lambda item: item[1])
        if best_sell_price <= best_buy_price:
            continue
        profit_abs = round(best_sell_price - best_buy_price, 2)
        profit_pct = round((profit_abs / best_buy_price) * 100, 2)
        if profit_abs < settings.min_profit_absolute:
            continue
        if profit_pct < settings.min_profit_percent:
            continue
        if best_buy_price > settings.max_buy_price:
            continue
        opportunity = ArbOpportunity(
            card_name=card.name,
            set_code=card.set_code,
            best_buy_vendor=best_buy_vendor,
            best_buy_price=best_buy_price,
            best_sell_vendor=best_sell_vendor,
            best_sell_price=best_sell_price,
            profit_absolute=profit_abs,
            profit_percent=profit_pct,
            timestamp=iso_timestamp(),
        )
        opportunities.append(opportunity)
        logger.info(
            "Opportunity found for %s: buy at %s ($%.2f) sell at %s ($%.2f)",
            card.name,
            best_buy_vendor,
            best_buy_price,
            best_sell_vendor,
            best_sell_price,
        )
    opportunities.sort(key=lambda item: item.profit_absolute, reverse=True)
    truncated = opportunities[: settings.max_results_per_run]
    if len(truncated) < len(opportunities):
        logger.info("Truncated results from %s to %s based on MAX_RESULTS_PER_RUN", len(opportunities), len(truncated))
    logger.info("Scan completed with %s opportunities", len(truncated))
    return truncated
