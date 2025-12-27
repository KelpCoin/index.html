"""CLI for Supervisor operations."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Optional

from .rollback_engine import RollbackEngine, Snapshot, PendingChange
from .supervisor_daemon import SupervisorDaemon


DEFAULT_SUBSYSTEMS = [
    "queue-runner",
    "arbitrage",
    "learnbot",
    "dashboards",
    "primer-factory",
]


def build_daemon() -> SupervisorDaemon:
    return SupervisorDaemon(
        subsystems=DEFAULT_SUBSYSTEMS,
        policy_dir="policies",
        config_dir="config",
    )


def cmd_status(args: argparse.Namespace) -> None:
    daemon = build_daemon()
    print(json.dumps(daemon.status(), indent=2))


def cmd_freeze(args: argparse.Namespace) -> None:
    daemon = build_daemon()
    if args.unfreeze:
        daemon.manual_unfreeze(args.subsystem, approved_by="manual freeze override")
    else:
        daemon.freeze_subsystem(args.subsystem, reason="manual CLI freeze")
    print(f"Updated state for {args.subsystem}")


def cmd_rollback(args: argparse.Namespace) -> None:
    daemon = build_daemon()
    engine = daemon.rollback_engine
    latest = engine.base_dir / args.subsystem
    if not latest.exists():
        raise SystemExit("No snapshots available")
    snapshot_dirs = sorted([p for p in latest.iterdir() if p.is_dir()])
    if not snapshot_dirs:
        raise SystemExit("No snapshots available")
    target_dir = snapshot_dirs[-1] if args.to == "last-known-good" else latest / args.to
    meta_path = target_dir / "meta.json"
    if not meta_path.exists():
        raise SystemExit("Snapshot metadata missing")
    meta = json.loads(meta_path.read_text())
    snapshot = Snapshot(
        subsystem=args.subsystem,
        path=next(target_dir.glob("*")),
        created_at=meta.get("created_at", 0),
        approved_by=meta.get("approved_by", "unknown"),
        description=meta.get("description", ""),
    )
    daemon.rollback(snapshot, approved_by=args.approved_by)
    print(f"Rolled back {args.subsystem} to {target_dir.name}")


def cmd_resume(args: argparse.Namespace) -> None:
    daemon = build_daemon()
    for subsystem in DEFAULT_SUBSYSTEMS if args.subsystem == "all" else [args.subsystem]:
        daemon.manual_unfreeze(subsystem, approved_by=args.approved_by)
    print("Resumed requested subsystems.")


def cmd_run(args: argparse.Namespace) -> None:
    daemon = build_daemon()
    daemon.run()


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Supervisor CLI")
    sub = parser.add_subparsers()

    status = sub.add_parser("status", help="Show supervisor status")
    status.set_defaults(func=cmd_status)

    freeze = sub.add_parser("freeze", help="Freeze or unfreeze a subsystem")
    freeze.add_argument("subsystem")
    freeze.add_argument("--unfreeze", action="store_true")
    freeze.set_defaults(func=cmd_freeze)

    rollback = sub.add_parser("rollback", help="Rollback subsystem policies/config")
    rollback.add_argument("subsystem")
    rollback.add_argument("--to", default="last-known-good")
    rollback.add_argument("--approved-by", required=True)
    rollback.set_defaults(func=cmd_rollback)

    resume = sub.add_parser("resume", help="Resume subsystems")
    resume.add_argument("subsystem")
    resume.add_argument("--approved-by", required=True)
    resume.set_defaults(func=cmd_resume)

    run = sub.add_parser("run", help="Run supervisor daemon")
    run.set_defaults(func=cmd_run)

    return parser


def main(argv: Optional[list] = None) -> None:
    parser = create_parser()
    args = parser.parse_args(argv)
    if hasattr(args, "func"):
        args.func(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
