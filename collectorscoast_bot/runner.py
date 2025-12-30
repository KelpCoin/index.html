"""Orchestrates picking feed items and posting tweets."""
from __future__ import annotations

from typing import Iterable

from .config import settings
from .feed import Movement, load_feed
from .history import HistoryStore
from .logger import logger
from .templates import arbitrage_summary, movement_summary
from .twitter_client import post_tweet


class BotRunner:
    def __init__(self, history: HistoryStore | None = None):
        self.history = history or HistoryStore(settings.history_file)

    def _select_candidate(self, movements: Iterable[Movement]) -> Movement | None:
        recent = self.history.recent_posts(settings.cooldown)
        logger.debug("Recent posts within cooldown: %s", recent)
        candidates = [m for m in movements if m.name not in recent]
        if not candidates:
            logger.info("No eligible candidates found; skipping")
            return None
        candidates.sort(key=lambda m: abs(m.change_pct), reverse=True)
        return candidates[0]

    def build_text(self, movement: Movement) -> str:
        if movement.category.lower() == "arbitrage":
            return arbitrage_summary(
                movement.name,
                movement.price_nzd,
                movement.change_pct,
                movement.reason,
            )
        return movement_summary(
            movement.name,
            movement.price_nzd,
            movement.change_pct,
            movement.reason,
        )

    def post_once(self) -> bool:
        logger.info("Loading feed from %s", settings.feed_url)
        movements = list(load_feed(settings.feed_url))
        candidate = self._select_candidate(movements)
        if not candidate:
            return False

        text = self.build_text(candidate)
        logger.info("Composed tweet:\n%s", text)
        posted = post_tweet(text, settings.bearer_token)
        if posted:
            self.history.record_post(candidate.name)
        return posted

    def posts_remaining_today(self) -> int:
        return max(0, settings.max_posts_per_day - self.history.total_posts_today())

    def should_post_now(self) -> bool:
        return self.posts_remaining_today() > 0
