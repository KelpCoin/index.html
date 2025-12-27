"""Rollback Engine for guarded configuration and policy changes."""
from __future__ import annotations

import json
import os
import shutil
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional


@dataclass
class PendingChange:
    subsystem: str
    path: Path
    description: str


@dataclass
class Snapshot:
    subsystem: str
    path: Path
    created_at: float
    approved_by: str
    description: str


class RollbackEngine:
    """Version-controlled snapshot store to ensure recoverability."""

    def __init__(self, policy_dir: str, config_dir: str, base_dir: str = "data/rollback") -> None:
        self.policy_dir = Path(policy_dir)
        self.config_dir = Path(config_dir)
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def detect_pending_changes(self) -> List[PendingChange]:
        """Mocked detection for pending changes.

        Real deployment should diff staging files vs. live files and emit PendingChange
        entries for safety review. Here we surface staged files found in policy/config dirs.
        """
        changes: List[PendingChange] = []
        for root in [self.policy_dir, self.config_dir]:
            if not root.exists():
                continue
            for path in root.glob("**/*.pending"):
                changes.append(
                    PendingChange(
                        subsystem=path.stem,
                        path=path,
                        description=f"Pending change detected at {path}",
                    )
                )
        return changes

    def capture_snapshot(self, change: PendingChange, approved_by: str) -> Snapshot:
        timestamp = time.time()
        target_dir = self.base_dir / change.subsystem / str(int(timestamp))
        target_dir.mkdir(parents=True, exist_ok=True)
        snapshot_path = target_dir / change.path.name.replace(".pending", "")
        shutil.copy2(change.path, snapshot_path)
        (target_dir / "meta.json").write_text(
            json.dumps(
                {
                    "approved_by": approved_by,
                    "description": change.description,
                    "source": str(change.path),
                    "created_at": timestamp,
                },
                indent=2,
            )
        )
        # Promote pending file to active
        active_path = change.path.with_suffix("")
        change.path.replace(active_path)
        return Snapshot(
            subsystem=change.subsystem,
            path=snapshot_path,
            created_at=timestamp,
            approved_by=approved_by,
            description=change.description,
        )

    def revert_snapshot(self, snapshot: Snapshot, approved_by: str) -> None:
        """Revert a snapshot to disk with human approval."""
        target = self._resolve_live_path(snapshot)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(snapshot.path, target)
        self._append_history(snapshot, approved_by=approved_by)

    def _resolve_live_path(self, snapshot: Snapshot) -> Path:
        if snapshot.path.suffix:
            filename = snapshot.path.name
        else:
            filename = f"{snapshot.subsystem}.json"
        return (self.policy_dir / filename) if "policy" in filename else (self.config_dir / filename)

    def _append_history(self, snapshot: Snapshot, approved_by: str) -> None:
        history_path = self.base_dir / snapshot.subsystem / "history.log"
        history_path.parent.mkdir(parents=True, exist_ok=True)
        with history_path.open("a", encoding="utf-8") as handle:
            handle.write(
                json.dumps(
                    {
                        "snapshot": str(snapshot.path),
                        "approved_by": approved_by,
                        "rolled_back_at": time.time(),
                        "description": snapshot.description,
                    }
                )
                + "\n"
            )


__all__ = ["RollbackEngine", "Snapshot", "PendingChange"]
