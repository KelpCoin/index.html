import datetime
import json
from pathlib import Path
from typing import Dict, List

from change_journal import ChangeJournal
from explanation_writer import ExplanationWriter
from file_utils import SafeFileManager
from governance import GovernanceException, GovernanceGate
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier


RECENCY_HALFLIFE_MINUTES = 60


def _load_candidates(gate: GovernanceGate, path: Path) -> List[Dict]:
    gate.guard("non_destructive_read", path)
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _score_candidate(candidate: Dict) -> Dict:
    observed_at = datetime.datetime.fromisoformat(candidate["observed_at"].replace("Z", "+00:00"))
    age_minutes = (datetime.datetime.utcnow() - observed_at).total_seconds() / 60
    recency_score = max(0.0, 1.0 - age_minutes / RECENCY_HALFLIFE_MINUTES)
    spread_score = min(1.0, candidate["spread"] * 5)
    confidence = round((recency_score * 0.6) + (spread_score * 0.4), 4)
    candidate["scores"] = {
        "recency": round(recency_score, 4),
        "spread": round(spread_score, 4),
        "confidence": confidence,
    }
    candidate["rescored_at"] = datetime.datetime.utcnow().isoformat() + "Z"
    return candidate


def run(gate: GovernanceGate, journal: ChangeJournal, explanations: ExplanationWriter, rollback: RollbackEngine, supervisor: SupervisorNotifier) -> None:
    source = Path("factory/arbitrage/candidates.json")
    manager = SafeFileManager(gate, journal, rollback, supervisor)

    if not source.exists():
        journal.log_no_material_change("arbitrage_rescore", "No candidates to rescore", {"source": str(source)})
        return

    try:
        candidates = _load_candidates(gate, source)
    except Exception as exc:  # noqa: BLE001
        journal.log_no_material_change("arbitrage_rescore", "Failed to read candidates", {"error": str(exc)})
        return

    rescored = [_score_candidate(dict(candidate)) for candidate in candidates]
    output_path = Path("factory/arbitrage/rescored_candidates.json")
    try:
        manager.write_json(
            output_path,
            rescored,
            action="overwrite",
            description="Rescored arbitrage candidates based on recency and spread",
            risk_level="high" if output_path.exists() else "standard",
        )
    except GovernanceException as exc:
        journal.log_no_material_change("arbitrage_rescore", "Pending approval before writing rescored list", {"reason": str(exc)})
        return

    explanations.write(
        "arbitrage_rescore",
        f"Rescored {len(rescored)} arbitrage candidates.",
        [
            f"Source: {source}",
            f"Output: {output_path}",
            "Scores combine recency and spread to rank confidence",
            "Governance gate enforced and previous version archived",
        ],
    )
