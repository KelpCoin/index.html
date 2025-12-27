"""Bot orchestrator for BrownEyeCortex.

Allows selective or batch execution of available bots via CLI flags.
"""

from __future__ import annotations

import argparse
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, List

# Constants
LOG_PATH = Path("C:/BrownEyeCortex/Logs/bots.log")


@dataclass
class Bot:
    """Represents a runnable bot."""

    name: str
    runner: Callable[[], str]

    def run(self) -> str:
        """Execute the bot and return a status message."""
        return self.runner()


def setup_logging() -> None:
    """Configure application logging to write to the designated log file."""
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=LOG_PATH,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )


# Bot implementations (placeholders for real integration)
def run_council_arbiter() -> str:
    # Replace with real bot invocation
    return "Council arbiter bot completed successfully."


def run_artifact_scoring() -> str:
    # Replace with real bot invocation
    return "Artifact scoring bot completed successfully."


def run_law_collector() -> str:
    # Replace with real bot invocation
    return "Law collector bot completed successfully."


def run_market_estimator() -> str:
    # Replace with real bot invocation
    return "Market estimator bot completed successfully."


BOT_REGISTRY = {
    "arbitrage": Bot("Council arbiter bot", run_council_arbiter),
    "scoring": Bot("Artifact scoring bot", run_artifact_scoring),
    "knowledge": Bot("Law collector bot", run_law_collector),
    "market": Bot("Market estimator bot", run_market_estimator),
}


def parse_args(argv: List[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run BrownEyeCortex bots.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--all", action="store_true", help="Run all bots.")
    group.add_argument("--only", choices=["scoring", "arbitrage", "knowledge"], help="Run only the specified bot type.")
    return parser.parse_args(argv)


def select_bots(args: argparse.Namespace) -> Iterable[Bot]:
    if args.all or not args.only:
        return BOT_REGISTRY.values()

    selected_bot = BOT_REGISTRY.get(args.only)
    if not selected_bot:
        raise ValueError(f"Unsupported bot selection: {args.only}")
    return [selected_bot]


def run_bots(bots: Iterable[Bot]) -> None:
    for bot in bots:
        result = bot.run()
        logging.info("%s | %s", bot.name, result)


def main(argv: List[str] | None = None) -> None:
    setup_logging()
    args = parse_args(argv)
    bots_to_run = select_bots(args)
    run_bots(bots_to_run)


if __name__ == "__main__":
    main()
