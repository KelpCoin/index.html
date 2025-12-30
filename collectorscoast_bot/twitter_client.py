"""Minimal X/Twitter client with retry and rate-limit awareness."""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from typing import Any

from .logger import logger

API_URL = "https://api.twitter.com/2/tweets"


def _build_request(payload: dict[str, Any], bearer_token: str) -> urllib.request.Request:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(API_URL, data=body, method="POST")
    request.add_header("Authorization", f"Bearer {bearer_token}")
    request.add_header("Content-Type", "application/json")
    return request


def post_tweet(text: str, bearer_token: str | None) -> bool:
    """Send a tweet. Returns True if successful."""
    if not bearer_token:
        logger.warning("No bearer token configured; skipping live tweet")
        return False

    payload = {"text": text}
    retries = 3
    backoff = 2
    for attempt in range(1, retries + 1):
        request = _build_request(payload, bearer_token)
        try:
            with urllib.request.urlopen(request) as response:  # noqa: S310 - controlled URL
                logger.info("Tweet posted: %s", response.read())
                return True
        except urllib.error.HTTPError as exc:
            if exc.code in {429, 500, 503}:
                logger.warning(
                    "API returned %s on attempt %s; backing off %ss",
                    exc.code,
                    attempt,
                    backoff,
                )
                time.sleep(backoff)
                backoff *= 2
                continue
            logger.error("Tweet failed with HTTP error: %s", exc)
            return False
        except urllib.error.URLError as exc:  # pragma: no cover - network dependent
            logger.error("Network error: %s", exc)
            time.sleep(backoff)
            backoff *= 2
    return False
