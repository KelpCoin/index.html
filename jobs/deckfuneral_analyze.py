from collections import Counter
from pathlib import Path
from typing import Dict, List

from change_journal import ChangeJournal
from explanation_writer import ExplanationWriter
from file_utils import SafeFileManager
from governance import GovernanceException, GovernanceGate
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier


def _parse_log(log_content: str) -> Dict[str, int]:
    counters = Counter()
    for line in log_content.splitlines():
        if "FAILURE" in line:
            counters["failures"] += 1
        if "NOTE" in line:
            counters["notes"] += 1
        if "RESILIENCE" in line:
            counters["resilience"] += 1
    return counters


def _summarize(log_content: str, counters: Dict[str, int]) -> str:
    bullets: List[str] = []
    for line in log_content.splitlines():
        if "FAILURE" in line or "NOTE" in line:
            bullets.append(line.split(" ", 1)[1] if " " in line else line)
    bullets.append(f"Resilience signals: {counters.get('resilience', 0)}")
    return "\n".join(bullets)


def run(gate: GovernanceGate, journal: ChangeJournal, explanations: ExplanationWriter, rollback: RollbackEngine, supervisor: SupervisorNotifier) -> None:
    log_path = Path("data/deckfuneral/logs/sample.log")
    report_dir = Path("artifacts/analyses/deckfuneral")
    report_dir.mkdir(parents=True, exist_ok=True)
    manager = SafeFileManager(gate, journal, rollback, supervisor)

    if not log_path.exists():
        journal.log_no_material_change("deckfuneral_analyze", "No deck funeral logs found", {"log_path": str(log_path)})
        return

    gate.guard("non_destructive_read", log_path)
    log_content = log_path.read_text(encoding="utf-8")
    counters = _parse_log(log_content)
    summary = _summarize(log_content, counters)

    report_content = "\n".join(
        [
            "# Deck Funeral Analysis",
            "",
            f"Source log: {log_path}",
            "",
            "## Observations",
            summary,
            "",
            "## Metrics",
            f"Failures: {counters.get('failures', 0)}",
            f"Notes: {counters.get('notes', 0)}",
            f"Resilience signals: {counters.get('resilience', 0)}",
        ]
    )
    report_file = report_dir / "deckfuneral_report.md"
    try:
        manager.write_text(
            report_file,
            report_content,
            action="overwrite",
            description="Updated deck funeral analysis report",
            risk_level="high" if report_file.exists() else "standard",
        )
    except GovernanceException as exc:
        journal.log_no_material_change("deckfuneral_analyze", "Approval required before writing analysis", {"reason": str(exc)})
        return

    explanations.write(
        "deckfuneral_analyze",
        "Deck funeral analysis completed.",
        [
            f"Source log analyzed: {log_path}",
            f"Report saved to: {report_file}",
            f"Failures detected: {counters.get('failures', 0)}",
            "Governance check enforced prior to report write",
        ],
    )
