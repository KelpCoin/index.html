"""Track posting history to avoid repetition and enforce cooldowns."""
from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import DefaultDict, Iterable

from .logger import logger


class HistoryStore:
    def __init__(self, path: str):
        self.path = Path(path)
        self.path.touch(exist_ok=True)

    def _load(self) -> DefaultDict[str, list[str]]:
        if not self.path.read_text().strip():
            return defaultdict(list)
        try:
            data = json.loads(self.path.read_text())
            return defaultdict(list, data)
        except json.JSONDecodeError:  # pragma: no cover - defensive
            logger.warning("History file invalid, resetting: %s", self.path)
            return defaultdict(list)

    def _save(self, data: DefaultDict[str, list[str]]):
        self.path.write_text(json.dumps(data, indent=2))

    def record_post(self, card_name: str, when: datetime | None = None) -> None:
        when = when or datetime.now(timezone.utc)
        data = self._load()
        data[card_name].append(when.isoformat())
        self._save(data)
        logger.info("Recorded post for %s at %s", card_name, when)

    def last_post_time(self, card_name: str) -> datetime | None:
        data = self._load()
        if not data.get(card_name):
            return None
        return datetime.fromisoformat(data[card_name][-1])

    def recent_posts(self, within: timedelta) -> set[str]:
        now = datetime.now(timezone.utc)
        data = self._load()
        recent: set[str] = set()
        for name, timestamps in data.items():
            for ts in timestamps:
                try:
                    if now - datetime.fromisoformat(ts) <= within:
                        recent.add(name)
                        break
                except ValueError:  # pragma: no cover - defensive
                    continue
        return recent

    def total_posts_today(self) -> int:
        now = datetime.now(timezone.utc)
        data = self._load()
        count = 0
        for timestamps in data.values():
            for ts in timestamps:
                try:
                    if datetime.fromisoformat(ts).date() == now.date():
                        count += 1
                except ValueError:  # pragma: no cover - defensive
                    continue
        return count

    def purge_older_than(self, horizon: timedelta) -> None:
        now = datetime.now(timezone.utc)
        data = self._load()
        changed = False
        for name, timestamps in list(data.items()):
            filtered: list[str] = []
            for ts in timestamps:
                try:
                    if now - datetime.fromisoformat(ts) <= horizon:
                        filtered.append(ts)
                except ValueError:
                    continue
            if filtered:
                data[name] = filtered
            else:
                data.pop(name, None)
            changed = True
        if changed:
            self._save(data)
            logger.debug("Purged old history entries")
