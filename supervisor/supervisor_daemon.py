"""
Supervisor Daemon for the BrownEye Cortex control-plane.
Defensive, idempotent, human-overridable supervisor that wraps all subsystems.
"""
from __future__ import annotations

import logging
import os
import queue
import time
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional

from .rollback_engine import RollbackEngine, Snapshot
from .safety_rules import SafetyRules, SafetyViolation
from .observability import HealthHeartbeat, IncidentLogger


DEFAULT_RATE_LIMIT_PER_MIN = 60
DISCORD_WEBHOOK_ENV = "SUPERVISOR_DISCORD_WEBHOOK"


@dataclass
class SubsystemState:
    name: str
    healthy: bool = True
    last_heartbeat: float = field(default_factory=time.time)
    frozen: bool = False
    notes: List[str] = field(default_factory=list)

    def mark_heartbeat(self) -> None:
        self.last_heartbeat = time.time()


class SupervisorDaemon:
    """Long-running supervisor orchestrating BrownEye Cortex subsystems."""

    def __init__(
        self,
        subsystems: Iterable[str],
        policy_dir: str,
        config_dir: str,
        log_path: str = "supervisor/supervisor.log",
        rate_limit_per_min: int = DEFAULT_RATE_LIMIT_PER_MIN,
    ) -> None:
        self.logger = logging.getLogger("supervisor")
        self.logger.setLevel(logging.INFO)
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        handler = logging.FileHandler(log_path)
        handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
        self.logger.addHandler(handler)

        self.states: Dict[str, SubsystemState] = {
            name: SubsystemState(name=name) for name in subsystems
        }
        self.policy_dir = policy_dir
        self.config_dir = config_dir
        self.rate_limit_per_min = max(1, rate_limit_per_min)
        self.action_bucket: queue.Queue = queue.Queue()
        self.rollback_engine = RollbackEngine(policy_dir=policy_dir, config_dir=config_dir)
        self.rules = SafetyRules()
        self.heartbeat = HealthHeartbeat(path="supervisor/heartbeat.json")
        self.incidents = IncidentLogger(path="supervisor/incidents.log")

    def run(self) -> None:
        """Entry point for the long-running supervisor loop."""
        self.logger.info("Supervisor starting with defensive defaults.")
        while True:
            self._tick()
            time.sleep(1)

    def _tick(self) -> None:
        self._monitor_logs()
        self._monitor_policies()
        self._process_actions()
        self._emit_heartbeat()

    def _monitor_logs(self) -> None:
        # Placeholder for real log monitoring
        # In production, tail subsystem logs and detect crash patterns.
        for state in self.states.values():
            stale = time.time() - state.last_heartbeat > 60
            if stale and not state.frozen:
                self._restart_subsystem(state, reason="Heartbeat stale")

    def _monitor_policies(self) -> None:
        changes = self.rollback_engine.detect_pending_changes()
        for change in changes:
            violations = self.rules.evaluate_change(change)
            if violations:
                self._freeze(change.subsystem, violations)
            else:
                self.rollback_engine.capture_snapshot(change, approved_by="supervisor")
                self.logger.info("Policy change accepted for %s", change.subsystem)

    def _process_actions(self) -> None:
        # Rate limit actions to avoid tight loops.
        max_actions = self.rate_limit_per_min // 60 + 1
        processed = 0
        while not self.action_bucket.empty() and processed < max_actions:
            action = self.action_bucket.get()
            processed += 1
            try:
                action()
            except Exception as exc:  # noqa: BLE001 - defensive catch-all
                self._report(f"Action failed: {exc}")

    def _emit_heartbeat(self) -> None:
        status = {
            name: {
                "healthy": state.healthy,
                "frozen": state.frozen,
                "notes": state.notes,
                "last_heartbeat": state.last_heartbeat,
            }
            for name, state in self.states.items()
        }
        self.heartbeat.write(status)

    # --- Intervention methods ---
    def _restart_subsystem(self, state: SubsystemState, reason: str) -> None:
        self.logger.warning("Restarting %s: %s", state.name, reason)
        state.notes.append(f"restarted: {reason}")
        self.incidents.log_event(state.name, "restart", reason)
        self._alert(f"Restarting {state.name}: {reason}")
        state.mark_heartbeat()

    def _freeze(self, subsystem: str, violations: List[SafetyViolation]) -> None:
        state = self.states[subsystem]
        state.frozen = True
        state.healthy = False
        reasons = "; ".join(v.message for v in violations)
        self.logger.error("Freezing %s: %s", subsystem, reasons)
        self.incidents.log_event(subsystem, "freeze", reasons)
        self._alert(f"{subsystem} frozen: {reasons}")

    def freeze_subsystem(self, subsystem: str, reason: str) -> None:
        violation = SafetyViolation(
            code="manual-freeze",
            message=reason,
            rationale="Explicit operator or automation request to halt subsystem.",
        )
        self._freeze(subsystem, [violation])

    def manual_unfreeze(self, subsystem: str, approved_by: str) -> None:
        state = self.states[subsystem]
        state.frozen = False
        state.healthy = True
        state.notes.append(f"unfrozen by {approved_by}")
        self.incidents.log_event(subsystem, "unfreeze", f"approved by {approved_by}")

    def rollback(self, snapshot: Snapshot, approved_by: str) -> None:
        self.logger.warning("Rolling back %s approved by %s", snapshot.subsystem, approved_by)
        self.rollback_engine.revert_snapshot(snapshot, approved_by=approved_by)
        self.incidents.log_event(snapshot.subsystem, "rollback", f"approved by {approved_by}")
        self._alert(f"Rollback executed for {snapshot.subsystem} by {approved_by}")

    def _report(self, message: str) -> None:
        self.logger.error(message)
        self._alert(message)

    def _alert(self, message: str) -> None:
        # Always write to local log for recoverability.
        self.logger.info("ALERT: %s", message)
        webhook = os.environ.get(DISCORD_WEBHOOK_ENV)
        if not webhook:
            return
        try:
            import requests

            requests.post(webhook, json={"content": f"[Supervisor] {message}"}, timeout=5)
        except Exception:
            self.logger.warning("Failed to push alert to Discord")

    # --- External API for CLI ---
    def status(self) -> Dict[str, Dict[str, object]]:
        return {
            name: {
                "healthy": s.healthy,
                "frozen": s.frozen,
                "notes": list(s.notes),
                "last_heartbeat": s.last_heartbeat,
            }
            for name, s in self.states.items()
        }

    def enqueue_action(self, action) -> None:
        self.action_bucket.put(action)


if __name__ == "__main__":
    daemon = SupervisorDaemon(
        subsystems=["queue-runner", "arbitrage", "learnbot", "dashboards", "primer-factory"],
        policy_dir="policies",
        config_dir="config",
    )
    daemon.run()
