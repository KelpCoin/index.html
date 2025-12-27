# MTG Arbitrage Alert Bot

This project scans Magic: The Gathering card prices across multiple vendors, finds arbitrage opportunities, saves them as JSON artifacts, and posts summaries to Discord.

## Features
- Configurable vendor selection and profit thresholds.
- Price caching to reduce repeated vendor lookups (6-hour TTL).
- Graceful error handling: bad cards or vendor errors do not stop the run.
- Daily JSON artifacts and optional Discord alerts.

## Prerequisites
- Python 3.10+ available on PATH.
- PowerShell (for the helper script, optional).
- Dependencies: `requests` and `python-dotenv`.

## Setup
1. Clone or place this folder at `C:\\BrownEyeCortex\\MTG_Arbiter`.
2. Copy `config/settings.example.env` to `config/settings.env` and fill in real values:
   - `DISCORD_WEBHOOK_URL` must be a valid Discord webhook or leave the placeholder to skip posting.
   - Adjust thresholds (`MIN_PROFIT_ABSOLUTE`, `MIN_PROFIT_PERCENT`, `MAX_BUY_PRICE`) as needed.
   - Toggle vendors with `ENABLE_VENDOR_*` flags (`true` or `false`).
3. Install dependencies:
   ```powershell
   pip install requests python-dotenv
   ```
4. Edit `data/input_cards.txt` with one card per line. Optional set codes go in square brackets, for example:
   ```
   Orcish Bowmasters
   Sol Ring [2ED]
   Plateau [REV]
   ```

## Running
- From PowerShell (recommended):
  ```powershell
  ./run_arbiter.ps1
  ```
- Or directly:
  ```powershell
  python src/main.py
  ```

Artifacts are written to `artifacts/daily/YYYY-MM-DD_arbitrage.json`. Logs live at `logs/arbiter.log`.

## Notes
- Vendor integrations use placeholder simulations. Replace the `fetch_price` implementations in `src/price_sources.py` with real API calls when credentials are available.
- The bot will skip Discord posting if the webhook is missing or still set to the placeholder.
- The program never stops on a single failed vendor or card; errors are logged and processing continues.
