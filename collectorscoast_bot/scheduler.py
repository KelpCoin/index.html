"""Very small scheduler to randomize posting windows."""
from __future__ import annotations

import random
import threading
from datetime import datetime, time, timedelta, timezone

from .logger import logger


class PostScheduler:
    def __init__(self, worker_callable):
        self.worker_callable = worker_callable
        self._timer: threading.Timer | None = None

    def _random_time_within(self, start: time, end: time) -> datetime:
        now = datetime.now(timezone.utc)
        start_dt = datetime.combine(now.date(), start, tzinfo=timezone.utc)
        end_dt = datetime.combine(now.date(), end, tzinfo=timezone.utc)
        delta_seconds = int((end_dt - start_dt).total_seconds())
        offset = random.randint(0, max(0, delta_seconds))
        return start_dt + timedelta(seconds=offset)

    def schedule_next(self) -> datetime | None:
        windows = [
            (time(0, 0), time(11, 0)),
            (time(11, 0), time(16, 0)),
            (time(16, 0), time(23, 59)),
        ]
        start, end = random.choice(windows)
        run_at = self._random_time_within(start, end)
        delay = max(0, (run_at - datetime.now(timezone.utc)).total_seconds())
        self._timer = threading.Timer(delay, self.worker_callable)
        self._timer.daemon = True
        self._timer.start()
        logger.info("Next post scheduled at %s", run_at)
        return run_at

    def cancel(self) -> None:
        if self._timer and self._timer.is_alive():
            self._timer.cancel()
            logger.info("Next scheduled post cancelled")
