"""Governance gate implementing the "ask when unsure" behavior.

The gate enforces an approval pause for risky or low-confidence actions and writes
requests to ``C:\\BrownEyeCortex\\Logs\\Approvals\\pending_requests.jsonl``. If a
Discord webhook URL is available (``CORTEX_DISCORD_WEBHOOK``), a notification is sent
without adding new dependencies.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional

from .paths import ensure_parent, resolve_windows_path

GOVERNANCE_WIN_PATH = r"C:\\BrownEyeCortex\\Data\\System\\governance.json"
PENDING_REQUESTS_WIN_PATH = r"C:\\BrownEyeCortex\\Logs\\Approvals\\pending_requests.jsonl"
DEFAULT_GOVERNANCE = {
    "ask_when_unsure": True,
    "confidence_threshold": 0.65,
}


@dataclass
class GovernanceContext:
    """Describes the action under evaluation."""

    job_name: str
    confidence: float
    touches_money: bool = False
    overwrites_files: bool = False
    deletes_data: bool = False
    changes_behavior: bool = False
    summary: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)

    def risk_flagged(self, threshold: float) -> bool:
        return (
            self.confidence < threshold
            or self.touches_money
            or self.overwrites_files
            or self.deletes_data
            or self.changes_behavior
        )


class GovernanceGate:
    """Implements the ask-when-unsure approval pause."""

    def __init__(self, governance_path: Optional[str | Path] = None) -> None:
        self.governance_path = ensure_parent(
            resolve_windows_path(governance_path or GOVERNANCE_WIN_PATH)
        )
        self.pending_requests_path = ensure_parent(
            resolve_windows_path(PENDING_REQUESTS_WIN_PATH)
        )
        self._config = self._load_or_initialize()

    def _load_or_initialize(self) -> Dict[str, Any]:
        if self.governance_path.exists():
            with self.governance_path.open("r", encoding="utf-8") as handle:
                return json.load(handle)

        with self.governance_path.open("w", encoding="utf-8") as handle:
            json.dump(DEFAULT_GOVERNANCE, handle, indent=2)
        return DEFAULT_GOVERNANCE.copy()

    def _timestamp(self) -> str:
        return _dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    def should_pause(self, context: GovernanceContext) -> bool:
        ask_when_unsure = self._config.get("ask_when_unsure", True)
        threshold = float(self._config.get("confidence_threshold", 0.65))
        if not ask_when_unsure:
            return False
        return context.risk_flagged(threshold)

    def record_pending(self, context: GovernanceContext) -> Dict[str, Any]:
        request = {
            "timestamp": self._timestamp(),
            "job_name": context.job_name,
            "confidence": context.confidence,
            "touches_money": context.touches_money,
            "overwrites_files": context.overwrites_files,
            "deletes_data": context.deletes_data,
            "changes_behavior": context.changes_behavior,
            "summary": context.summary,
            "metadata": context.metadata,
            "status": "pending-approval",
        }
        with self.pending_requests_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(request) + "\n")
        self._notify_discord(request)
        return request

    def _notify_discord(self, request: Dict[str, Any]) -> None:
        webhook = os.environ.get("CORTEX_DISCORD_WEBHOOK")
        if not webhook:
            return

        payload = json.dumps(
            {
                "content": (
                    "BrownEye Cortex paused an action for approval:\n"
                    f"Job: {request['job_name']}\n"
                    f"Reason: {request['summary'] or 'ask when unsure trigger'}\n"
                    f"Confidence: {request['confidence']}"
                )
            }
        ).encode("utf-8")
        req = urllib.request.Request(
            webhook,
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req):
                pass
        except urllib.error.URLError:
            # Do not fail the automation if the webhook is unreachable.
            return

    def guard(self, context: GovernanceContext) -> bool:
        """Return True if execution should pause and record a pending approval."""
        if self.should_pause(context):
            self.record_pending(context)
            return True
        return False
