import json
import datetime
from pathlib import Path
from typing import Any, Dict, Optional


class ChangeJournal:
    def __init__(self, log_path: Path | str = "logs/change_journal.log"):
        self.log_path = Path(log_path)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def _write_entry(self, entry: Dict[str, Any]) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry) + "\n")

    def log_change(self, action: str, target_path: Path | str, description: str, metadata: Optional[Dict[str, Any]] = None) -> None:
        entry = {
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "action": action,
            "target_path": str(target_path),
            "description": description,
            "metadata": metadata or {},
        }
        self._write_entry(entry)

    def log_no_material_change(self, action: str, reason: str, metadata: Optional[Dict[str, Any]] = None) -> None:
        entry = {
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "action": action,
            "status": "no_change",
            "reason": reason,
            "metadata": metadata or {},
        }
        self._write_entry(entry)
