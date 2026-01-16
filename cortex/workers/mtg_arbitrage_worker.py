from __future__ import annotations

import json
from pathlib import Path

from cortex.modules.mtg_arbitrage import MTGArbitrageModule

CONFIG_PATH = Path(__file__).parents[1] / "config" / "cortex_config.json"


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text())
    palette = json.loads((Path(__file__).parents[1] / "palette" / "palette.json").read_text())
    module_config = config.get("modules", {}).get("mtg_arbitrage", {})
    module = MTGArbitrageModule(module_config, palette)
    result = module.run()
    output_path = Path(config.get("data_dir", "../data")) / "mtg_arbitrage_output.json"
    output_path.write_text(json.dumps(result.payload, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
