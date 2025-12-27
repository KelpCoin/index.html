import shutil
import datetime
from pathlib import Path
from typing import Optional


class RollbackEngine:
    def __init__(self, archive_dir: Path | str = "archives/versions"):
        self.archive_dir = Path(archive_dir)
        self.archive_dir.mkdir(parents=True, exist_ok=True)

    def version_file(self, path: Path | str, label: Optional[str] = None):
        path = Path(path)
        if not path.exists():
            return None
        timestamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        suffix = f"_{label}" if label else ""
        archive_path = self.archive_dir / f"{path.name}.{timestamp}{suffix}"
        shutil.copy2(path, archive_path)
        return archive_path
