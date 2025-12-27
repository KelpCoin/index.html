import json
import traceback
from pathlib import Path
from typing import Callable, Dict, List

from change_journal import ChangeJournal
from explanation_writer import ExplanationWriter
from governance import GovernanceGate, GovernanceException
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier

from jobs import get_job_registry


class QueueRunner:
    def __init__(self, queue_path: Path | str = "config/job_queue.json"):
        self.queue_path = Path(queue_path)
        self.gate = GovernanceGate()
        self.journal = ChangeJournal()
        self.explanations = ExplanationWriter()
        self.rollback = RollbackEngine()
        self.supervisor = SupervisorNotifier()
        self.job_registry = get_job_registry()
        self.failure_count = 0

    def _load_queue(self) -> List[str]:
        if not self.queue_path.exists():
            return list(self.job_registry.keys())
        with self.queue_path.open("r", encoding="utf-8") as handle:
            return json.load(handle).get("jobs", [])

    def run(self) -> None:
        jobs = self._load_queue()
        for job_name in jobs:
            handler = self.job_registry.get(job_name)
            if not handler:
                self.journal.log_no_material_change("queue", f"Job {job_name} missing from registry", {"job": job_name})
                continue
            try:
                handler(self.gate, self.journal, self.explanations, self.rollback, self.supervisor)
                self.failure_count = 0
            except GovernanceException as exc:
                self.failure_count += 1
                self.journal.log_no_material_change(job_name, f"Paused for approval: {exc}", {"job": job_name})
            except Exception as exc:  # noqa: BLE001
                self.failure_count += 1
                self.journal.log_no_material_change(job_name, "Job failed; continuing queue", {"error": str(exc), "job": job_name})
                self.supervisor.log_incident(
                    event="job_failure",
                    severity="warning",
                    details={"job": job_name, "error": str(exc), "traceback": traceback.format_exc()},
                )
            if self.failure_count >= self.gate.policies.get("supervisor_thresholds", {}).get("repeated_failures", 3):
                self.supervisor.log_incident(
                    event="repeated_failures",
                    severity="critical",
                    details={"consecutive_failures": self.failure_count, "job": job_name},
                )
                self.failure_count = 0


def main() -> None:
    runner = QueueRunner()
    runner.run()


if __name__ == "__main__":
    main()
