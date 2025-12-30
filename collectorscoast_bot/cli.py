"""Command-line interface for manual or scheduled posting."""
from __future__ import annotations

import argparse
import time

from .config import settings
from .logger import logger
from .runner import BotRunner
from .scheduler import PostScheduler


class BotCLI:
    def __init__(self):
        self.runner = BotRunner()
        self.scheduler = PostScheduler(self._run_and_reschedule)

    def _run_and_reschedule(self):
        self.safe_post_once()
        if self.runner.posts_remaining_today() > 0:
            self.scheduler.schedule_next()
        else:
            logger.info("Daily cap reached; not scheduling additional posts today")

    def safe_post_once(self):
        if not self.runner.should_post_now():
            logger.info("Daily limit reached (%s); skipping", settings.max_posts_per_day)
            return
        self.runner.post_once()

    def manual_post(self):
        self.safe_post_once()

    def schedule_next(self):
        if not self.runner.should_post_now():
            logger.info("Daily limit reached (%s); not scheduling", settings.max_posts_per_day)
            return
        run_at = self.scheduler.schedule_next()
        logger.info("Scheduled next post for %s", run_at)

    def cancel_schedule(self):
        self.scheduler.cancel()

    def run_forever(self):
        logger.info("Worker running. Press Ctrl+C to exit.")
        self.schedule_next()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Stopping scheduler…")
            self.cancel_schedule()



def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CollectorsCoast MTG bot")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("manual-post", help="Send a single post immediately")
    subparsers.add_parser("schedule-next", help="Schedule the next post within a random window")
    subparsers.add_parser("cancel-schedule", help="Cancel the pending scheduled post")
    subparsers.add_parser("worker", help="Run the background worker")
    return parser


def main(argv: list[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    cli = BotCLI()
    if args.command == "manual-post":
        cli.manual_post()
    elif args.command == "schedule-next":
        cli.schedule_next()
    elif args.command == "cancel-schedule":
        cli.cancel_schedule()
    elif args.command == "worker":
        cli.run_forever()


if __name__ == "__main__":  # pragma: no cover
    main()
