from __future__ import annotations

from typing import Any, Dict, List


def build_mtg_summary(payload: Dict[str, Any]) -> str:
    opportunities = payload.get("opportunities", [])
    spikes = payload.get("spikes", [])
    lines = [
        "MTG Arbitrage Summary",
        f"Opportunities under € threshold: {len(opportunities)}",
        f"Detected spikes: {len(spikes)}",
    ]
    for card in opportunities[:5]:
        lines.append(f"Buy: {card['card_name']} €{card['eur']} / ${card['usd']}")
    for spike in spikes[:5]:
        lines.append(
            f"Spike: {spike['card_name']} {spike['delta_pct']}% (${spike['prev_usd']} → ${spike['new_usd']})"
        )
    return "\n".join(lines)
