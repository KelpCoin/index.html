import json
import datetime
from pathlib import Path
from typing import Any, Dict


class SupervisorNotifier:
    def __init__(self, log_path: Path | str = "logs/supervisor_incidents.log"):
        self.log_path = Path(log_path)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log_incident(self, event: str, severity: str, details: Dict[str, Any]) -> None:
        entry = {
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "event": event,
            "severity": severity,
            "details": details,
        }
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry) + "\n")
