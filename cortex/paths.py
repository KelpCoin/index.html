"""Path handling utilities to mirror required Windows locations cross-platform.

The helpers translate mandated Windows-style paths into a writable location on the
current OS. On Windows, the original path is used. On POSIX systems we mirror the
structure under a configurable root (``CORTEX_WINDOWS_MIRROR``) that defaults to a
local ``cortex_mirror`` folder. This makes the helpers idempotent and keeps file IO
portable during development while staying compatible with production targets.
"""
from __future__ import annotations

import os
from pathlib import Path, PureWindowsPath
from typing import Optional


def _mirror_root() -> Path:
    """Return the root directory used to mirror Windows paths on non-Windows hosts."""
    override = os.environ.get("CORTEX_WINDOWS_MIRROR")
    if override:
        return Path(override).expanduser()
    return Path.cwd() / "cortex_mirror"


def resolve_windows_path(windows_path: str, mirror_root: Optional[Path] = None) -> Path:
    """Resolve a Windows-styled path to a usable Path object on the current OS.

    Args:
        windows_path: The canonical Windows path requested by the Cortex design.
        mirror_root: Optional override for the mirror directory on non-Windows hosts.

    Returns:
        A ``Path`` that can be read/written on the active platform.
    """
    pure = PureWindowsPath(windows_path)

    # On Windows, we can use the path directly.
    if os.name == "nt":
        return Path(pure)

    # On POSIX, strip the drive letter and mirror the rest of the path.
    parts_without_drive = pure.parts[1:] if pure.drive else pure.parts
    root = mirror_root or _mirror_root()
    return root.joinpath(*parts_without_drive)


def ensure_parent(path: Path) -> Path:
    """Create parent directories for ``path`` and return the path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    return path
