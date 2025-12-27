"""Self-test probes for the Supervisor."""
from __future__ import annotations

import time
from typing import Dict

from .safety_rules import SafetyRules


def run_probes() -> Dict[str, bool]:
    """Execute cheap, idempotent sanity probes."""
    results = {
        "clock": abs(time.time() - time.monotonic()) < 5,
        "safety_rules": _safety_rules_probe(),
    }
    return results


def _safety_rules_probe() -> bool:
    rules = SafetyRules()
    violations = rules.evaluate_runtime({"daily_transactions": rules.daily_transaction_cap - 1})
    return len(violations) == 0


__all__ = ["run_probes"]
