"""Simple logging utilities."""
from __future__ import annotations

import logging
from .config import settings


def configure_logger() -> logging.Logger:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(message)s",
    )
    return logging.getLogger("collectorscoast_bot")


logger = configure_logger()
