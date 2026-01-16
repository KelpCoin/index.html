from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import requests
from bs4 import BeautifulSoup

from cortex.modules.base import CortexModule, ModuleResult
from cortex.modules.discord_summary import build_mtg_summary


class MTGArbitrageModule(CortexModule):
    name = "mtg_arbitrage"
    version = "1.0.0"

    def _init_db(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.config["db_path"])
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS cards (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                set_code TEXT,
                scryfall_id TEXT,
                UNIQUE(name, set_code)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS prices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                card_name TEXT,
                usd REAL,
                eur REAL,
                nzd REAL,
                aud REAL,
                source TEXT,
                created_at TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS spikes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                card_name TEXT,
                prev_usd REAL,
                new_usd REAL,
                delta_pct REAL,
                detected_at TEXT
            )
            """
        )
        return conn

    def _fetch_mtgstocks_movers(self) -> List[Dict[str, str]]:
        response = requests.get("https://www.mtgstocks.com/", timeout=20)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        cards = []
        for table in soup.select("table"):
            for row in table.select("tbody tr"):
                cols = [col.get_text(strip=True) for col in row.select("td")]
                if len(cols) < 2:
                    continue
                name = cols[0]
                cards.append({"name": name})
        return cards[:25]

    def _fetch_scryfall_price(self, name: str) -> Optional[Dict[str, Any]]:
        response = requests.get(
            "https://api.scryfall.com/cards/named",
            params={"fuzzy": name},
            timeout=20,
        )
        if response.status_code != 200:
            return None
        data = response.json()
        prices = data.get("prices", {})
        return {
            "name": data.get("name"),
            "set": data.get("set"),
            "scryfall_id": data.get("id"),
            "usd": float(prices.get("usd") or 0),
            "eur": float(prices.get("eur") or 0),
        }

    def _calculate_conversions(self, usd: float) -> Dict[str, float]:
        nzd = usd / self.config.get("aud_to_usd", 0.66) / self.config.get("nzd_to_aud", 0.92)
        aud = usd / self.config.get("aud_to_usd", 0.66)
        return {"nzd": round(nzd, 2), "aud": round(aud, 2)}

    def _detect_spike(self, conn: sqlite3.Connection, card_name: str, usd: float) -> Optional[Dict[str, Any]]:
        window_hours = self.config.get("spike_window_hours", 24)
        cutoff = (datetime.utcnow() - timedelta(hours=window_hours)).isoformat() + "Z"
        cursor = conn.execute(
            "SELECT usd FROM prices WHERE card_name = ? AND created_at >= ? ORDER BY created_at DESC LIMIT 1",
            (card_name, cutoff),
        )
        row = cursor.fetchone()
        if row and row[0] > 0:
            prev = row[0]
            delta_pct = ((usd - prev) / prev) * 100
            if delta_pct >= 15:
                return {"prev_usd": prev, "new_usd": usd, "delta_pct": round(delta_pct, 2)}
        return None

    def run(self) -> ModuleResult:
        conn = self._init_db()
        movers = self._fetch_mtgstocks_movers()
        opportunities = []
        spikes = []
        for card in movers:
            price_data = self._fetch_scryfall_price(card["name"])
            if not price_data:
                continue
            conversions = self._calculate_conversions(price_data["usd"])
            price_entry = {
                "card_name": price_data["name"],
                "usd": price_data["usd"],
                "eur": price_data["eur"],
                "nzd": conversions["nzd"],
                "aud": conversions["aud"],
                "source": "scryfall",
                "created_at": datetime.utcnow().isoformat() + "Z",
            }
            conn.execute(
                "INSERT INTO prices (card_name, usd, eur, nzd, aud, source, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    price_entry["card_name"],
                    price_entry["usd"],
                    price_entry["eur"],
                    price_entry["nzd"],
                    price_entry["aud"],
                    price_entry["source"],
                    price_entry["created_at"],
                ),
            )
            if price_entry["eur"] > 0 and price_entry["eur"] <= self.config.get("eur_buy_threshold", 50):
                opportunities.append(price_entry)
            spike = self._detect_spike(conn, price_entry["card_name"], price_entry["usd"])
            if spike:
                spikes.append({"card_name": price_entry["card_name"], **spike})
                conn.execute(
                    "INSERT INTO spikes (card_name, prev_usd, new_usd, delta_pct, detected_at) VALUES (?, ?, ?, ?, ?)",
                    (
                        price_entry["card_name"],
                        spike["prev_usd"],
                        spike["new_usd"],
                        spike["delta_pct"],
                        datetime.utcnow().isoformat() + "Z",
                    ),
                )
        conn.commit()
        conn.close()
        summary = f"MTG arbitrage scanned {len(movers)} movers, found {len(opportunities)} under €{self.config.get('eur_buy_threshold', 50)} and {len(spikes)} spikes."
        payload_summary = build_mtg_summary({\"opportunities\": opportunities, \"spikes\": spikes})
        payload = {
            "opportunities": opportunities,
            "spikes": spikes,
            "count": len(movers),
            "discord_summary": payload_summary,
        }
        return ModuleResult(
            name=self.name,
            fingerprint=self.fingerprint(),
            summary=summary,
            payload=payload,
            timestamp=self.timestamp(),
        )
