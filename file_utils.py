import json
from pathlib import Path
from typing import Any, Dict, Optional

from governance import GovernanceGate, GovernanceException
from change_journal import ChangeJournal
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier


class SafeFileManager:
    def __init__(self, gate: GovernanceGate, journal: ChangeJournal, rollback: RollbackEngine, supervisor: Optional[SupervisorNotifier] = None):
        self.gate = gate
        self.journal = journal
        self.rollback = rollback
        self.supervisor = supervisor

    def _notify_supervisor(self, action: str, path: Path, risk_level: str) -> None:
        if self.supervisor and (risk_level == "high" or action == "policy_change"):
            self.supervisor.log_incident(
                event="risky_action",
                severity="warning",
                details={"action": action, "path": str(path), "risk_level": risk_level},
            )

    def write_json(self, path: Path | str, data: Any, action: str, description: str, risk_level: str = "standard") -> Path:
        path = Path(path)
        context = {"action": action, "description": description}
        self.gate.guard(action, path, context=context, risk_level=risk_level)
        self.rollback.version_file(path, label="backup")
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
        self.journal.log_change(action, path, description, {"risk_level": risk_level})
        self._notify_supervisor(action, path, risk_level)
        return path

    def write_text(self, path: Path | str, content: str, action: str, description: str, risk_level: str = "standard") -> Path:
        path = Path(path)
        context = {"action": action, "description": description}
        self.gate.guard(action, path, context=context, risk_level=risk_level)
        self.rollback.version_file(path, label="backup")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        self.journal.log_change(action, path, description, {"risk_level": risk_level})
        self._notify_supervisor(action, path, risk_level)
        return path

    def ensure_readable(self, path: Path | str) -> Any:
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"Required file missing: {path}")
        self.gate.guard("non_destructive_read", path)
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle) if path.suffix == ".json" else handle.read()
