import datetime
import itertools
import json
from pathlib import Path
from typing import Dict, List

from change_journal import ChangeJournal
from explanation_writer import ExplanationWriter
from file_utils import SafeFileManager
from governance import GovernanceException, GovernanceGate
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier


def _load_market_data(gate: GovernanceGate, source: Path) -> List[Dict]:
    gate.guard("non_destructive_read", source)
    with source.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _identify_arbitrage_opportunities(market_data: List[Dict], min_spread: float = 0.03) -> List[Dict]:
    candidates = []
    grouped: Dict[str, List[Dict]] = {}
    for record in market_data:
        grouped.setdefault(record["asset"], []).append(record)

    for asset, records in grouped.items():
        for buy, sell in itertools.permutations(records, 2):
            spread = (sell["price"] - buy["price"]) / buy["price"]
            if spread >= min_spread:
                candidates.append(
                    {
                        "asset": asset,
                        "buy_market": buy["market"],
                        "sell_market": sell["market"],
                        "buy_price": buy["price"],
                        "sell_price": sell["price"],
                        "spread": round(spread, 4),
                        "observed_at": datetime.datetime.utcnow().isoformat() + "Z",
                    }
                )
    return candidates


def run(gate: GovernanceGate, journal: ChangeJournal, explanations: ExplanationWriter, rollback: RollbackEngine, supervisor: SupervisorNotifier) -> None:
    source = Path("data/market_data/mock_upstream.json")
    manager = SafeFileManager(gate, journal, rollback, supervisor)

    try:
        market_data = _load_market_data(gate, source)
    except FileNotFoundError:
        journal.log_no_material_change("arbitrage_seed", "Upstream market data missing", {})
        return

    candidates = _identify_arbitrage_opportunities(market_data)
    if not candidates:
        journal.log_no_material_change("arbitrage_seed", "No spreads above threshold", {"source": str(source)})
        explanations.write(
            "arbitrage_seed",
            "Run completed with no qualifying opportunities.",
            ["Market data scanned", "No spreads exceeded threshold"],
        )
        return

    output_path = Path("factory/arbitrage/candidates.json")
    try:
        manager.write_json(
            output_path,
            candidates,
            action="overwrite",
            description="Updated arbitrage candidates from mock upstream data",
            risk_level="high" if output_path.exists() else "standard",
        )
    except GovernanceException as exc:
        journal.log_no_material_change("arbitrage_seed", "Pending approval before writing candidates", {"reason": str(exc)})
        return

    explanations.write(
        "arbitrage_seed",
        f"Identified {len(candidates)} arbitrage candidates from mock data.",
        [
            f"Input source: {source}",
            f"Output saved to: {output_path}",
            "Governance gate enforced before write",
            "Previous file versioned when overwritten",
        ],
    )
