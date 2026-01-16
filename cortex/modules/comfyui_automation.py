from __future__ import annotations

import json
import socket
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from cortex.modules.base import CortexModule, ModuleResult


class ComfyUIAutomationModule(CortexModule):
    name = "comfyui_automation"
    version = "1.0.0"

    def _port_open(self, port: int) -> bool:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            return sock.connect_ex(("127.0.0.1", port)) == 0

    def run(self) -> ModuleResult:
        root = Path(self.config.get("comfyui_root", "D:/ComfyUI"))
        port = int(self.config.get("launch_port", 8188))
        status = {
            "root_exists": root.exists(),
            "main_py": (root / "main.py").exists(),
            "port_open": self._port_open(port),
            "checked_at": datetime.utcnow().isoformat() + "Z",
        }
        output_path = root / "cortex_status.json"
        if root.exists():
            output_path.write_text(json.dumps(status, indent=2), encoding="utf-8")
        summary = "ComfyUI status checked."
        return ModuleResult(
            name=self.name,
            fingerprint=self.fingerprint(),
            summary=summary,
            payload=status,
            timestamp=self.timestamp(),
        )
