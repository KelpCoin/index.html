"""Change journal writer for BrownEye Cortex.

This helper ensures every script can write a human-readable entry into the mandated
``C:\\BrownEyeCortex\\Logs\\System\\change_journal.log`` file while remaining
portable across platforms. The file is appended to, never overwritten.
"""
from __future__ import annotations

import datetime as _dt
from pathlib import Path
from typing import Optional

from .paths import ensure_parent, resolve_windows_path

CHANGE_JOURNAL_WIN_PATH = r"C:\\BrownEyeCortex\\Logs\\System\\change_journal.log"


class ChangeJournal:
    """Append-only change journal writer."""

    def __init__(self, path: Optional[str | Path] = None) -> None:
        target = resolve_windows_path(path or CHANGE_JOURNAL_WIN_PATH)
        self.path = ensure_parent(target)

    def _timestamp(self) -> str:
        return _dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    def log_change(
        self,
        module: str,
        changed_item: str,
        change_category: str,
        approval: str,
        auto_applied: bool,
    ) -> None:
        """Record a change event in the journal.

        Args:
            module: The module making the change.
            changed_item: Description of what was changed (policy, file, job, dataset).
            change_category: Free-form category to aid filtering.
            approval: "auto-applied" or a human approver name.
            auto_applied: Whether the system applied the change automatically.
        """
        mode = "auto-applied" if auto_applied else f"human-approved:{approval}"
        entry = (
            f"[{self._timestamp()} UTC] module={module} category={change_category} "
            f"item={changed_item} mode={mode}\n"
        )
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(entry)

    def log_no_material_change(self, module: str) -> None:
        """Record that no change was performed by the module."""
        entry = f"[{self._timestamp()} UTC] module={module} no material change\n"
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(entry)
