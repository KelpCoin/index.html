"""Observability utilities for the Supervisor."""
from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict


@dataclass
class HealthHeartbeat:
    path: str

    def write(self, status: Dict[str, object]) -> None:
        payload = {
            "generated_at": time.time(),
            "status": status,
        }
        Path(self.path).write_text(json.dumps(payload, indent=2))


@dataclass
class IncidentLogger:
    path: str

    def log_event(self, subsystem: str, event: str, details: str) -> None:
        timestamp = time.time()
        line = json.dumps(
            {
                "timestamp": timestamp,
                "subsystem": subsystem,
                "event": event,
                "details": details,
            }
        )
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with Path(self.path).open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")


__all__ = ["HealthHeartbeat", "IncidentLogger"]
