"""Configuration utilities for the CollectorsCoast automation bot."""
from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import timedelta


@dataclass
class Settings:
    """Runtime configuration loaded from environment variables."""

    bearer_token: str | None
    api_key: str | None
    api_secret: str | None
    access_token: str | None
    access_token_secret: str | None
    feed_url: str
    ticker_url: str
    max_posts_per_day: int = 4
    cooldown: timedelta = timedelta(hours=72)
    log_level: str = "INFO"
    history_file: str = "post_history.json"

    @classmethod
    def load(cls) -> "Settings":
        return cls(
            bearer_token=os.getenv("X_BEARER_TOKEN"),
            api_key=os.getenv("X_API_KEY"),
            api_secret=os.getenv("X_API_SECRET"),
            access_token=os.getenv("X_ACCESS_TOKEN"),
            access_token_secret=os.getenv("X_ACCESS_TOKEN_SECRET"),
            feed_url=os.getenv("FEED_URL", "data/sample_feed.json"),
            ticker_url=os.getenv("TICKER_URL", "https://collectorscoast.example/ticker"),
            max_posts_per_day=int(os.getenv("MAX_POSTS_PER_DAY", "4")),
            cooldown=timedelta(hours=int(os.getenv("COOLDOWN_HOURS", "72"))),
            log_level=os.getenv("LOG_LEVEL", "INFO"),
            history_file=os.getenv("HISTORY_FILE", "post_history.json"),
        )


settings = Settings.load()
