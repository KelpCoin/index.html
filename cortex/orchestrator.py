from __future__ import annotations

import json
import os
import queue
import random
import sqlite3
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

from cortex.modules import (
    ComfyUIAutomationModule,
    DeckPricingModule,
    ForgeSimulationModule,
    MTGArbitrageModule,
)

CONFIG_PATH = Path(__file__).parent / "config" / "cortex_config.json"


@dataclass
class CycleLog:
    cycle_id: str
    timestamp: str
    modules: List[Dict[str, Any]]
    seed_tasks_processed: int
    supercycle: bool


class LLMClient:
    def __init__(self, config: Dict[str, Any]) -> None:
        self.provider = config.get("provider", "ollama")
        self.model = config.get("model", "llama3.1")
        self.api_base = config.get("api_base", "http://localhost:11434")
        self.timeout = config.get("timeout_seconds", 90)
        self.api_key_env = config.get("api_key_env", "OPENAI_API_KEY")

    def _ollama_chat(self, messages: List[Dict[str, str]]) -> str:
        payload = {"model": self.model, "messages": messages, "stream": False}
        response = requests.post(f"{self.api_base}/api/chat", json=payload, timeout=self.timeout)
        response.raise_for_status()
        return response.json().get("message", {}).get("content", "")

    def _openai_chat(self, messages: List[Dict[str, str]]) -> str:
        api_key = os.getenv(self.api_key_env)
        if not api_key:
            raise RuntimeError("OpenAI API key not configured")
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {"model": self.model, "messages": messages}
        response = requests.post("https://api.openai.com/v1/chat/completions", json=payload, headers=headers, timeout=self.timeout)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]

    def chat(self, messages: List[Dict[str, str]]) -> str:
        try:
            if self.provider == "openai":
                return self._openai_chat(messages)
            return self._ollama_chat(messages)
        except Exception as exc:
            return f"[LOCAL-FALLBACK] {exc}. " + " ".join(m["content"] for m in messages if m["role"] == "user")


class CortexOrchestrator:
    def __init__(self, config_path: Path) -> None:
        self.config = self._load_config(config_path)
        self.palette = self._load_palette(Path(__file__).parent / "palette" / "palette.json")
        self.loop_interval = self.config.get("loop_interval_seconds", 180)
        self.data_dir = Path(self.config.get("data_dir", "../data")).resolve()
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.log_path = Path(self.config.get("log_path", "../logs/cortex.log")).resolve()
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.seed_task_queue: "queue.Queue[str]" = queue.Queue()
        self.discord_webhook_url = self.config.get("discord_webhook_url", "")
        self.llm_client = LLMClient(self.config.get("llm", {}))
        self.generator_prompt = (Path(__file__).parent / "prompts" / "generator_system_prompt.txt").read_text()
        self.critic_prompt = (Path(__file__).parent / "prompts" / "critic_system_prompt.txt").read_text()
        self.synthesizer_prompt = (Path(__file__).parent / "prompts" / "synthesizer_instructions.txt").read_text()
        self._load_seed_tasks()
        self.modules = self._init_modules()

    def _load_config(self, config_path: Path) -> Dict[str, Any]:
        return json.loads(config_path.read_text())

    def _load_palette(self, palette_path: Path) -> Dict[str, Any]:
        return json.loads(palette_path.read_text())

    def _init_modules(self) -> List[Any]:
        modules = []
        cfg = self.config.get("modules", {})
        if cfg.get("mtg_arbitrage", {}).get("enabled"):
            modules.append(MTGArbitrageModule(cfg.get("mtg_arbitrage", {}), self.palette))
        if cfg.get("forge_simulation", {}).get("enabled"):
            modules.append(ForgeSimulationModule(cfg.get("forge_simulation", {}), self.palette))
        if cfg.get("deck_pricing", {}).get("enabled"):
            modules.append(DeckPricingModule(cfg.get("deck_pricing", {}), self.palette))
        if cfg.get("comfyui_automation", {}).get("enabled"):
            modules.append(ComfyUIAutomationModule(cfg.get("comfyui_automation", {}), self.palette))
        return modules

    def _load_seed_tasks(self) -> None:
        for task in self.config.get("seed_tasks", []):
            self.seed_task_queue.put(task)
        external_seed_path = self.data_dir / "seed_tasks.json"
        if external_seed_path.exists():
            tasks = json.loads(external_seed_path.read_text())
            for task in tasks.get("tasks", []):
                self.seed_task_queue.put(task)

    def _log(self, message: str, level: str = "info") -> None:
        colors = self.palette.get("terminal_colors", {})
        color = colors.get(level, "")
        reset = colors.get("reset", "")
        timestamp = datetime.utcnow().isoformat() + "Z"
        line = f"[{timestamp}] {message}"
        print(f"{color}{line}{reset}")
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")

    def _send_discord(self, content: str) -> None:
        if not self.discord_webhook_url:
            return
        payload = {"content": content}
        try:
            requests.post(self.discord_webhook_url, json=payload, timeout=10)
        except Exception as exc:
            self._log(f"Discord webhook failed: {exc}", level="warn")

    def _device_mode(self) -> str:
        try:
            import torch

            return "cuda" if torch.cuda.is_available() else "cpu"
        except Exception:
            return "cpu"

    def _peggy_mod(self, text: str) -> str:
        tone = "Warm, indulgent, body-positive, focused on comfort and satisfaction. "
        return tone + text.strip()

    def _dual_llm_refine(self, task: str) -> str:
        generator_messages = [
            {"role": "system", "content": self.generator_prompt},
            {"role": "user", "content": task},
        ]
        draft = self.llm_client.chat(generator_messages)
        critic_messages = [
            {"role": "system", "content": self.critic_prompt},
            {"role": "user", "content": draft},
        ]
        critique = self.llm_client.chat(critic_messages)
        synth_messages = [
            {"role": "system", "content": self.synthesizer_prompt},
            {"role": "user", "content": f"Task: {task}\nDraft: {draft}\nCritique: {critique}"},
        ]
        final = self.llm_client.chat(synth_messages)
        return self._peggy_mod(final)

    def _process_seed_tasks(self) -> List[str]:
        results = []
        while not self.seed_task_queue.empty():
            task = self.seed_task_queue.get()
            self._log(f"Running seed task: {task}")
            result = self._dual_llm_refine(task)
            results.append(result)
            summary_path = self.data_dir / "seed_task_outputs.sqlite"
            with sqlite3.connect(summary_path) as conn:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS seed_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, task TEXT, output TEXT, created_at TEXT)"
                )
                conn.execute(
                    "INSERT INTO seed_tasks (task, output, created_at) VALUES (?, ?, ?)",
                    (task, result, datetime.utcnow().isoformat() + "Z"),
                )
        return results

    def _check_supercycle(self) -> bool:
        trigger_path = self.data_dir / "supercycle.trigger"
        if trigger_path.exists():
            trigger_path.unlink()
            return True
        return False

    def run_cycle(self, supercycle: bool = False) -> CycleLog:
        cycle_id = f"CYCLE-{int(time.time())}-{random.randint(1000, 9999)}"
        module_logs = []
        for module in self.modules:
            if not supercycle and module.name == "comfyui_automation":
                continue
            result = module.run()
            if result.name == "mtg_arbitrage":
                discord_summary = result.payload.get("discord_summary", "")
                if discord_summary:
                    self._send_discord(self._peggy_mod(discord_summary[:1900]))
            if result.name == "forge_simulation":
                self._send_discord(self._peggy_mod(result.summary[:1900]))
            module_logs.append(
                {
                    "name": result.name,
                    "fingerprint": result.fingerprint,
                    "summary": result.summary,
                    "timestamp": result.timestamp,
                }
            )
        seed_results = self._process_seed_tasks()
        for summary in seed_results:
            self._send_discord(summary[:1900])
        cycle_log = CycleLog(
            cycle_id=cycle_id,
            timestamp=datetime.utcnow().isoformat() + "Z",
            modules=module_logs,
            seed_tasks_processed=len(seed_results),
            supercycle=supercycle,
        )
        self._log(f"Completed {cycle_id} | supercycle={supercycle} | modules={len(module_logs)}")
        self._send_discord(self._peggy_mod(f"Cycle {cycle_id} complete. Modules run: {len(module_logs)}."))
        return cycle_log

    def run_forever(self) -> None:
        self._log(f"Starting Cortex on {self._device_mode()} with palette {self.palette.get('name')}")
        while True:
            supercycle = self._check_supercycle()
            self.run_cycle(supercycle=supercycle)
            time.sleep(self.loop_interval)


def main() -> None:
    orchestrator = CortexOrchestrator(CONFIG_PATH)
    if "--supercycle" in sys.argv:
        orchestrator.run_cycle(supercycle=True)
        return
    orchestrator.run_forever()


if __name__ == "__main__":
    main()
