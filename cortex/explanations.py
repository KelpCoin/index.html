"""Self-explanation file writer for jobs."""
from __future__ import annotations

import datetime as _dt
import json
from pathlib import Path
from typing import Dict, Optional

from .paths import ensure_parent, resolve_windows_path

EXPLANATION_LOG_ROOT = r"C:\\BrownEyeCortex\\Logs\\Explanations"


class ExplanationWriter:
    """Generates structured explanations for completed jobs."""

    def __init__(self, root_path: Optional[str | Path] = None) -> None:
        target_root = resolve_windows_path(root_path or EXPLANATION_LOG_ROOT)
        self.root = ensure_parent(target_root)

    def _timestamp(self) -> str:
        return _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    def write(
        self,
        job_name: str,
        job_type: str,
        input_summary: str,
        decision: str,
        risk_level: str,
        confidence: float,
        human_summary: str,
        metadata: Optional[Dict[str, object]] = None,
    ) -> Path:
        """Write an explanation JSON file for the job run."""
        timestamp = self._timestamp()
        file_path = ensure_parent(self.root / f"{job_name}_{timestamp}.json")
        payload = {
            "timestamp": timestamp,
            "job_type": job_type,
            "input_summary": input_summary,
            "decision": decision,
            "risk_level": risk_level,
            "confidence": confidence,
            "human_summary": human_summary,
            "metadata": metadata or {},
        }
        with file_path.open("w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
        return file_path
