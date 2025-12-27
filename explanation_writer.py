import datetime
from pathlib import Path
from typing import Dict, List


class ExplanationWriter:
    def __init__(self, base_dir: Path | str = "artifacts/explanations"):
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def write(self, job_name: str, summary: str, bullet_points: List[str], metadata: Dict[str, str] | None = None) -> Path:
        timestamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        job_dir = self.base_dir / job_name
        job_dir.mkdir(parents=True, exist_ok=True)
        path = job_dir / f"{timestamp}.md"
        lines = [f"# {job_name} run at {timestamp}", "", summary, "", "## Details"]
        lines.extend([f"- {point}" for point in bullet_points])
        if metadata:
            lines.append("")
            lines.append("## Metadata")
            lines.extend([f"- {key}: {value}" for key, value in metadata.items()])
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path
