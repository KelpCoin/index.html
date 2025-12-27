from __future__ import annotations

import json
from typing import List

import requests

from models import ArbOpportunity, Settings
from utils import get_logger

logger = get_logger()


def _format_opportunity(opportunity: ArbOpportunity) -> str:
    set_part = f" [{opportunity.set_code}]" if opportunity.set_code else ""
    return (
        f"{opportunity.card_name}{set_part}: Buy {opportunity.best_buy_vendor} ${opportunity.best_buy_price:.2f} "
        f"-> Sell {opportunity.best_sell_vendor} ${opportunity.best_sell_price:.2f} "
        f"(+${opportunity.profit_absolute:.2f}, {opportunity.profit_percent:.2f}%)"
    )


def send_discord_summary(opportunities: List[ArbOpportunity], settings: Settings) -> None:
    if not settings.discord_webhook_url or "REPLACE_WITH_REAL_WEBHOOK" in settings.discord_webhook_url:
        logger.warning("Discord webhook not configured; skipping Discord notification")
        return
    total_hits = len(opportunities)
    min_abs = settings.min_profit_absolute
    min_pct = settings.min_profit_percent
    if total_hits == 0:
        content = f"{settings.brand_tag} Daily Arbitrage Scan\nNo hits today. Keep hunting!"
    else:
        preview = "\n".join(_format_opportunity(item) for item in opportunities[:5])
        content = (
            f"{settings.brand_tag} Daily Arbitrage Scan\n"
            f"Total hits: {total_hits} (min profit ${min_abs} / {min_pct}%)\n"
            f"Example hits:\n{preview}\n"
            f"Support: {settings.patreon_link}"
        )
    payload = {"content": content}
    try:
        response = requests.post(settings.discord_webhook_url, json=payload, timeout=10)
        if response.status_code >= 400:
            logger.error("Discord webhook responded with status %s: %s", response.status_code, response.text)
        else:
            logger.info("Discord notification sent (hits: %s)", total_hits)
    except Exception as exc:
        logger.error("Failed to send Discord notification: %s", exc)
