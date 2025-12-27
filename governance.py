import json
import datetime
from pathlib import Path
from typing import Any, Dict, Optional


class GovernanceException(Exception):
    """Raised when a governance rule requires manual approval."""

    def __init__(self, action: str, target_path: Path, context: Optional[Dict[str, Any]] = None):
        context = context or {}
        message = (
            f"Governance approval required for action '{action}' on {target_path}. "
            f"Context: {context}. Submit approval in governance/approvals to proceed."
        )
        super().__init__(message)
        self.action = action
        self.target_path = target_path
        self.context = context


class GovernanceGate:
    def __init__(self, policies_path: Path | str = "governance/policies.json"):
        self.policies_path = Path(policies_path)
        self.pending_dir = Path("governance/pending")
        self.approvals_dir = Path("governance/approvals")
        self.pending_dir.mkdir(parents=True, exist_ok=True)
        self.approvals_dir.mkdir(parents=True, exist_ok=True)
        self._policies = self._load_policies()

    def _load_policies(self) -> Dict[str, Any]:
        if not self.policies_path.exists():
            default = {
                "auto_approve": ["non_destructive_read"],
                "require_manual_approval": ["overwrite", "policy_change"],
                "supervisor_thresholds": {"repeated_failures": 3, "mass_overwrite_count": 5},
            }
            self.policies_path.parent.mkdir(parents=True, exist_ok=True)
            self.policies_path.write_text(json.dumps(default, indent=2), encoding="utf-8")
            return default
        with self.policies_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    @property
    def policies(self) -> Dict[str, Any]:
        return self._policies

    def guard(self, action: str, target_path: Path | str, context: Optional[Dict[str, Any]] = None, risk_level: str = "standard") -> None:
        """Enforce governance before writes. Raises GovernanceException when approval is needed."""
        context = context or {}
        target_path = Path(target_path)

        if action in self._policies.get("auto_approve", []):
            return

        approval_file = self.approvals_dir / f"{action}.approved"
        requires_manual = action in self._policies.get("require_manual_approval", []) or risk_level == "high"
        is_overwrite = target_path.exists()

        if requires_manual or is_overwrite:
            if not approval_file.exists():
                pending_record = {
                    "action": action,
                    "target": str(target_path),
                    "context": context,
                    "risk_level": risk_level,
                    "requested_at": datetime.datetime.utcnow().isoformat() + "Z",
                }
                pending_path = self.pending_dir / f"pending_{action}_{int(datetime.datetime.utcnow().timestamp())}.json"
                pending_path.write_text(json.dumps(pending_record, indent=2), encoding="utf-8")
                raise GovernanceException(action, target_path, context)
            approval_file.unlink(missing_ok=True)

    def refresh(self) -> None:
        self._policies = self._load_policies()
