"""Safety rules codify guardrails for the Supervisor."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional

from .rollback_engine import PendingChange


@dataclass
class SafetyViolation:
    code: str
    message: str
    rationale: str


class SafetyRules:
    def __init__(self) -> None:
        self.daily_transaction_cap = 500  # never exceed X daily attempts
        self.auto_listing_enabled = False  # gated
        self.protected_directories = ["/", "/etc", "/var/lib", "core"]
        self.profit_floor = -1000  # pause if catastrophic
        self.learnbot_confidence_floor = 0.6

    def evaluate_change(self, change: PendingChange) -> List[SafetyViolation]:
        violations: List[SafetyViolation] = []
        path = str(change.path)
        for protected in self.protected_directories:
            if protected in path:
                violations.append(
                    SafetyViolation(
                        code="protected-path",
                        message=f"Attempt to modify protected area: {path}",
                        rationale="Core directories are immutable without manual override.",
                    )
                )
        if "auto-listing" in path and not self.auto_listing_enabled:
            violations.append(
                SafetyViolation(
                    code="auto-listing-disabled",
                    message="Auto-listing requires manual gating.",
                    rationale="Prevents runaway listing without oversight.",
                )
            )
        return violations

    def evaluate_runtime(self, metrics: Dict[str, float]) -> List[SafetyViolation]:
        violations: List[SafetyViolation] = []
        if metrics.get("daily_transactions", 0) > self.daily_transaction_cap:
            violations.append(
                SafetyViolation(
                    code="transaction-cap",
                    message="Daily transaction attempts exceeded cap.",
                    rationale="Prevents runaway loops and meets compliance limits.",
                )
            )
        if metrics.get("profit_delta", 0) < self.profit_floor:
            violations.append(
                SafetyViolation(
                    code="profit-floor",
                    message="Profits dropped catastrophically; pausing subsystems.",
                    rationale="Protects capital until human approves recovery plan.",
                )
            )
        if metrics.get("learnbot_confidence", 1) < self.learnbot_confidence_floor:
            violations.append(
                SafetyViolation(
                    code="learnbot-confidence",
                    message="LearnBot confidence too low; freeze suggestions.",
                    rationale="Avoids auto-publishing risky model outputs.",
                )
            )
        return violations


__all__ = ["SafetyRules", "SafetyViolation"]
