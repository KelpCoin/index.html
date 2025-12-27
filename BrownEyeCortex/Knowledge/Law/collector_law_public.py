"""
Knowledge ingestion bot for legally reusable law sources.

Rules implemented:
- Only scrape sources allowed by robots.txt (checked per domain and URL).
- Prefer government or open-license sources; logs a warning if license is unknown.
- Stores metadata per source (source_url, license, last_fetched, text_path).
- Outputs normalized text files into the data directory.
- Never bypasses logins or paywalls; only fetches plain public URLs.

This script is designed to run in a weekly PowerShell scheduled task, but it can
be executed directly via Python. All network requests use a conservative user
agent and a short timeout to avoid long-running jobs.
"""
from __future__ import annotations

import json
import logging
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List
from urllib.parse import urlparse
from urllib import robotparser

import requests
from bs4 import BeautifulSoup

# Base directories (mirrors the requested Windows layout).
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
METADATA_PATH = DATA_DIR / "metadata.jsonl"
USER_AGENT = "BrownEyeCortex-LegalCollector/1.0"
REQUEST_TIMEOUT = 20

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


@dataclass
class Source:
    """Describes a source to ingest."""

    url: str
    license: str | None
    label: str


# Curated list of publicly accessible, government or openly licensed sources.
# Additional sources can be appended while respecting the license guidance.
SOURCES: List[Source] = [
    Source(
        url="https://www.supremecourt.gov/opinions/slipopinion/23",
        license="Public Domain (U.S. Government Work)",
        label="SCOTUS slip opinions 2023 term",
    ),
    Source(
        url="https://www.justice.gov/archives/jm",
        license="Public Domain (U.S. Government Work)",
        label="Department of Justice Manual",
    ),
    Source(
        url="https://www.nist.gov/director/speeches-testimony",
        license="Public Domain (U.S. Government Work)",
        label="NIST speeches and testimony",
    ),
    Source(
        url="https://www.federalregister.gov/documents/search?conditions%5Bpublication_date%5D%5Bis%5D=&conditions%5Bterm%5D=privacy",
        license="Public Domain (U.S. Government Work)",
        label="Federal Register privacy-related notices",
    ),
    Source(
        url="https://www.oecd.org/legal/licence/",
        license="CC-BY-4.0",
        label="OECD legal license overview",
    ),
    Source(
        url="https://www.un.org/en/about-us/universal-declaration-of-human-rights",
        license=None,
        label="UDHR (license not clearly declared)",
    ),
]


def slugify(value: str) -> str:
    """Create a filesystem-safe slug from a string."""

    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "source"


def read_robot_parser(url: str, cache: Dict[str, robotparser.RobotFileParser]) -> robotparser.RobotFileParser:
    """Load and cache the robots.txt parser for a given URL's domain."""

    parsed = urlparse(url)
    domain = parsed.netloc
    if domain in cache:
        return cache[domain]

    robots_url = f"{parsed.scheme}://{domain}/robots.txt"
    rp = robotparser.RobotFileParser()
    rp.set_url(robots_url)
    try:
        rp.read()
    except Exception as exc:  # pragma: no cover - defensive logging
        logger.warning("Could not read robots.txt from %s (%s)", robots_url, exc)
    cache[domain] = rp
    return rp


def is_allowed(url: str, rp: robotparser.RobotFileParser) -> bool:
    """Check whether the URL is allowed by robots.txt."""

    try:
        return rp.can_fetch(USER_AGENT, url)
    except Exception:  # pragma: no cover - defensive logging
        return False


def fetch_html(url: str) -> str | None:
    """Fetch raw HTML content with safety constraints."""

    headers = {"User-Agent": USER_AGENT}
    try:
        response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
    except requests.RequestException as exc:
        logger.error("Request failed for %s: %s", url, exc)
        return None

    if response.status_code != 200:
        logger.warning("Skipping %s (HTTP %s)", url, response.status_code)
        return None

    return response.text


def extract_text(html: str, url: str) -> str:
    """Convert HTML to normalized text."""

    soup = BeautifulSoup(html, "html.parser")

    # Remove obvious non-content elements.
    for tag in soup(["script", "style", "noscript", "header", "footer", "nav"]):
        tag.decompose()

    text = soup.get_text(separator="\n")
    normalized_lines = [line.strip() for line in text.splitlines() if line.strip()]
    normalized = "\n".join(normalized_lines)

    if not normalized:
        logger.warning("No text extracted from %s", url)

    return normalized


def load_existing_metadata() -> Dict[str, dict]:
    """Load current metadata entries keyed by source_url."""

    entries: Dict[str, dict] = {}
    if not METADATA_PATH.exists():
        return entries

    with METADATA_PATH.open("r", encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            source_url = record.get("source_url")
            if source_url:
                entries[source_url] = record
    return entries


def persist_metadata(entries: Iterable[dict]) -> None:
    """Write metadata back to disk as JSONL."""

    with METADATA_PATH.open("w", encoding="utf-8") as handle:
        for record in entries:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def process_sources(sources: Iterable[Source]) -> None:
    """Ingest the provided list of sources."""

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    cache: Dict[str, robotparser.RobotFileParser] = {}
    metadata = load_existing_metadata()

    for source in sources:
        rp = read_robot_parser(source.url, cache)
        if not is_allowed(source.url, rp):
            logger.info("Skipped %s because robots.txt disallows it", source.url)
            continue

        if source.license is None:
            logger.warning("License unknown for %s; please verify reuse rights", source.url)

        html = fetch_html(source.url)
        if not html:
            continue

        text = extract_text(html, source.url)
        if not text:
            continue

        slug = slugify(source.label or source.url)
        text_path = DATA_DIR / f"{slug}.txt"
        text_path.write_text(text, encoding="utf-8")
        logger.info("Saved text for %s to %s", source.url, text_path)

        metadata[source.url] = {
            "source_url": source.url,
            "license": source.license or "Unknown",
            "last_fetched": datetime.now(timezone.utc).isoformat(),
            "text_path": str(text_path.relative_to(BASE_DIR)),
            "label": source.label,
        }

    persist_metadata(metadata.values())


def main() -> None:
    logger.info("Starting knowledge ingestion for %s sources", len(SOURCES))
    process_sources(SOURCES)
    logger.info("Ingestion complete. Metadata stored at %s", METADATA_PATH)


if __name__ == "__main__":
    sys.exit(main())
