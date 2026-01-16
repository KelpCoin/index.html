from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict


@dataclass
class ModuleResult:
    name: str
    fingerprint: str
    summary: str
    payload: Dict[str, Any]
    timestamp: str


class CortexModule:
    name: str = "base"
    version: str = "1.0.0"

    def __init__(self, config: Dict[str, Any], palette: Dict[str, Any]) -> None:
        self.config = config
        self.palette = palette

    def fingerprint(self) -> str:
        digest = hashlib.sha256(
            json.dumps({"name": self.name, "version": self.version, "config": self.config}, sort_keys=True).encode()
        ).hexdigest()
        return digest[:12]

    def run(self) -> ModuleResult:
        raise NotImplementedError

    @staticmethod
    def timestamp() -> str:
        return datetime.utcnow().isoformat() + "Z"
