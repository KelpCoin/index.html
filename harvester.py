"""Deck Harvester Bot for BrownEye Cortex.

Reads a text file of Moxfield and Manabox deck URLs, fetches their lists,
normalizes them, and writes JSON artifacts and logs as required by the
prompt.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import logging
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
from urllib import parse as urlparse
from urllib import request as urlrequest

RAW_DIR = Path(r"D:\\BROWNEYE_ARTIFACTS\\DeckPrimers\\Raw")
LOG_FILE = Path(r"D:\\BROWNEYE_ARTIFACTS\\DeckPrimers\\Logs\\harvester.log")

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DeckHarvesterBot/1.0"
MAX_RETRIES = 3
RETRY_DELAY = 2.0


@dataclass
class HarvestResult:
    url: str
    success: bool
    reason: Optional[str] = None


class DeckHarvester:
    def __init__(self) -> None:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        RAW_DIR.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(message)s",
            handlers=[
                logging.FileHandler(LOG_FILE, encoding="utf-8"),
                logging.StreamHandler(sys.stdout),
            ],
        )
        self.logger = logging.getLogger(__name__)

    def harvest_file(self, input_path: Path) -> List[HarvestResult]:
        urls = self._load_urls(input_path)
        results: List[HarvestResult] = []
        for url in urls:
            result = self.harvest_url(url)
            results.append(result)
        return results

    def harvest_url(self, url: str) -> HarvestResult:
        self.logger.info("Processing %s", url)
        parsed = urlparse.urlparse(url)
        domain = parsed.netloc.lower()
        try:
            if "moxfield" in domain:
                deck = self._harvest_moxfield(url)
            elif "manabox" in domain:
                deck = self._harvest_manabox(url)
            else:
                raise ValueError(f"Unsupported domain: {domain}")
            if deck is None:
                raise ValueError("Deck data could not be extracted")
            self._save_deck(deck)
            self.logger.info("Saved deck '%s'", deck.get("deck_name", "unknown"))
            return HarvestResult(url=url, success=True)
        except Exception as exc:  # noqa: BLE001
            self.logger.exception("Failed to harvest %s: %s", url, exc)
            return HarvestResult(url=url, success=False, reason=str(exc))

    def _load_urls(self, input_path: Path) -> List[str]:
        if not input_path.exists():
            raise FileNotFoundError(f"Input file not found: {input_path}")
        with input_path.open("r", encoding="utf-8") as f:
            lines = [line.strip() for line in f if line.strip()]
        if not lines:
            raise ValueError("Input file did not contain any deck URLs")
        return lines

    def _fetch_with_retries(self, url: str) -> str:
        last_error: Optional[Exception] = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                req = urlrequest.Request(url, headers={"User-Agent": USER_AGENT})
                with urlrequest.urlopen(req, timeout=20) as resp:
                    return resp.read().decode("utf-8", errors="replace")
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                self.logger.warning("Attempt %s/%s failed for %s: %s", attempt, MAX_RETRIES, url, exc)
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_DELAY)
        raise RuntimeError(f"Failed to fetch after {MAX_RETRIES} attempts: {last_error}")

    def _save_deck(self, deck: Dict[str, Any]) -> None:
        deck_name = deck.get("deck_name") or "deck"
        safe_name = self._sanitize_filename(deck_name)
        target_path = RAW_DIR / f"{safe_name}.json"
        with target_path.open("w", encoding="utf-8") as f:
            json.dump(deck, f, indent=2, ensure_ascii=False)

    def _sanitize_filename(self, name: str) -> str:
        cleaned = re.sub(r"[\\/:*?\"<>|]", "_", name)
        cleaned = cleaned.strip()
        return cleaned or "deck"

    def _harvest_moxfield(self, url: str) -> Optional[Dict[str, Any]]:
        deck_id = self._extract_moxfield_id(url)
        if not deck_id:
            raise ValueError("Could not extract Moxfield deck ID")
        api_url = f"https://api.moxfield.com/v2/decks/all/{deck_id}"
        try:
            raw_json = self._fetch_with_retries(api_url)
        except RuntimeError as exc:
            raise RuntimeError(f"Moxfield fetch failed: {exc}") from exc

        try:
            data = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON from Moxfield: {exc}") from exc

        deck_name = data.get("name") or deck_id
        commander_names = self._extract_commanders(data.get("commanders"))
        colors = data.get("colors") or data.get("colorIdentity") or []
        cards = self._extract_cards_from_board(data.get("mainboard") or {})
        price = self._extract_price(data.get("price") or data.get("prices") or {})

        return {
            "source": "moxfield",
            "url": url,
            "deck_name": deck_name,
            "commander": " / ".join(commander_names) if commander_names else None,
            "colors": colors,
            "cards": cards,
            "metadata": {
                "date_scraped": _dt.datetime.utcnow().isoformat() + "Z",
                "price_estimate": price,
            },
        }

    def _extract_moxfield_id(self, url: str) -> Optional[str]:
        parsed = urlparse.urlparse(url)
        parts = [p for p in parsed.path.split("/") if p]
        if "decks" in parts:
            idx = parts.index("decks")
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return None

    def _extract_commanders(self, commanders_blob: Any) -> List[str]:
        names: List[str] = []
        if isinstance(commanders_blob, dict):
            for entry in commanders_blob.values():
                if isinstance(entry, dict):
                    card = entry.get("card") or entry
                    name = card.get("name") if isinstance(card, dict) else None
                    if name:
                        names.append(name.strip())
        elif isinstance(commanders_blob, list):
            for entry in commanders_blob:
                if isinstance(entry, str):
                    names.append(entry.strip())
                elif isinstance(entry, dict):
                    name = entry.get("name") or entry.get("card", {}).get("name")
                    if name:
                        names.append(name.strip())
        return names

    def _extract_cards_from_board(self, board: Any) -> List[Dict[str, Any]]:
        cards: List[Dict[str, Any]] = []
        if isinstance(board, dict):
            iterable: Iterable[Any] = board.values()
        elif isinstance(board, list):
            iterable = board
        else:
            iterable = []

        for entry in iterable:
            if not isinstance(entry, dict):
                continue
            quantity = entry.get("quantity") or entry.get("qty") or entry.get("count")
            if quantity is None:
                continue
            card_info = entry.get("card") if isinstance(entry.get("card"), dict) else entry
            name = card_info.get("name") if isinstance(card_info, dict) else None
            if not name:
                continue
            type_line = card_info.get("type_line") or card_info.get("typeLine") or card_info.get("type") or ""
            cards.append(
                {
                    "name": name.strip(),
                    "qty": int(quantity),
                    "type": type_line.strip(),
                }
            )
        return cards

    def _extract_price(self, price_blob: Any) -> Optional[float]:
        if isinstance(price_blob, (int, float)):
            return float(price_blob)
        if isinstance(price_blob, dict):
            for key in ("usd", "paper", "price", "total", "estimate"):
                value = price_blob.get(key)
                if isinstance(value, (int, float)):
                    return float(value)
                if isinstance(value, str):
                    try:
                        return float(value)
                    except ValueError:
                        continue
        return None

    def _harvest_manabox(self, url: str) -> Optional[Dict[str, Any]]:
        try:
            html = self._fetch_with_retries(url)
        except RuntimeError as exc:
            raise RuntimeError(f"Manabox fetch failed: {exc}") from exc

        json_blob = self._extract_next_data(html)
        deck_payload = self._find_deck_payload(json_blob) if json_blob else None
        if not deck_payload:
            raise ValueError("Could not locate deck payload in Manabox page")

        deck_name = (
            deck_payload.get("name")
            or deck_payload.get("title")
            or deck_payload.get("slug")
            or "manabox_deck"
        )
        commander = deck_payload.get("commander") or deck_payload.get("commanderName")
        colors = deck_payload.get("colors") or deck_payload.get("colorIdentity") or []
        price = self._extract_price(deck_payload.get("price") or deck_payload.get("metadata", {}).get("price"))
        cards = self._extract_cards_from_board(deck_payload.get("cards") or [])
        if not cards:
            extra_cards = deck_payload.get("mainboard") or deck_payload.get("main")
            cards = self._extract_cards_from_board(extra_cards)

        return {
            "source": "manabox",
            "url": url,
            "deck_name": deck_name,
            "commander": commander,
            "colors": colors,
            "cards": cards,
            "metadata": {
                "date_scraped": _dt.datetime.utcnow().isoformat() + "Z",
                "price_estimate": price,
            },
        }

    def _extract_next_data(self, html: str) -> Optional[Dict[str, Any]]:
        match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(?P<data>{.*?})</script>', html, re.S)
        if not match:
            return None
        try:
            return json.loads(match.group("data"))
        except json.JSONDecodeError:
            return None

    def _find_deck_payload(self, blob: Any) -> Optional[Dict[str, Any]]:
        if isinstance(blob, dict):
            if "cards" in blob and isinstance(blob.get("cards"), list):
                return blob
            for value in blob.values():
                found = self._find_deck_payload(value)
                if found:
                    return found
        elif isinstance(blob, list):
            for item in blob:
                found = self._find_deck_payload(item)
                if found:
                    return found
        return None


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Harvest decks from Moxfield and Manabox URLs")
    parser.add_argument("input_file", type=Path, help="Path to text file containing deck URLs, one per line")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    harvester = DeckHarvester()
    results = harvester.harvest_file(args.input_file)
    successes = [r for r in results if r.success]
    failures = [r for r in results if not r.success]

    print("Harvest report")
    print(f"Successes: {len(successes)}")
    print(f"Failures: {len(failures)}")
    if failures:
        print("Failed URLs:")
        for result in failures:
            print(f"- {result.url}: {result.reason}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
