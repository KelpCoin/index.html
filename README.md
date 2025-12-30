# CollectorsCoast X/Twitter Bot

Lightweight Python worker that shares New Zealand MTG price movement and arbitrage notes for CollectorsCoast. It respects daily limits, randomizes posting windows, and avoids repeating the same card within 72 hours.

## Features
- Pulls top movers/arbitrage items from a JSON feed (local sample included).
- Friendly tweet templates with NZ disclaimer and CollectorsCoast ticker link.
- Limits to 4 posts per day, with randomized scheduling windows.
- Manual CLI trigger plus commands to schedule/cancel the next post or run a worker loop.
- Back-off retry handling and rate-limit awareness for X/Twitter API calls.

## Requirements
- Python 3.11+
- Network access to the JSON feed and X API (or run in dry-run mode without tokens)

Install dependencies (standard library only, so nothing to install) and make sure environment variables are set.

## Quickstart
1. Copy `.env.example` to `.env` and fill in your API credentials.
2. Activate the environment variables (`export $(grep -v '^#' .env | xargs)` on Linux/macOS).
3. Test a manual post:
   ```bash
   python -m collectorscoast_bot.cli manual-post
   ```
   If tokens are missing, the bot will log the tweet text but skip the live post.

## Running the worker
The worker schedules the next post within a random window (morning, afternoon, evening) and keeps running.
```bash
python -m collectorscoast_bot.cli worker
```
- `schedule-next`: schedule a single post without looping.
- `cancel-schedule`: cancel any pending timer.

## Feed format
The bot expects a JSON object with a `movements` array. See `data/sample_feed.json` for an example:
```json
{
  "movements": [
    {"name": "Jeweled Lotus", "price_nzd": 210.5, "change_pct": 8.5, "reason": "Commander demand spike after new legend reveals", "category": "mover"}
  ]
}
```

## Deployment notes
- Run on a small VPS (1 vCPU/1GB is fine). Install Python 3.11 and copy the repo.
- Store secrets in environment variables; never commit them.
- Use systemd or a process manager (e.g., `systemd` service) to run `python -m collectorscoast_bot.cli worker`.
- Log files can be redirected via standard output capture from your service manager.

## Safety and etiquette baked in
- Daily cap of 4 posts and cooldown of 72 hours per card.
- Friendly tone with reasons for movement; no aggressive calls to buy.
- Hashtags only when relevant (#mtgfinance, #mtgnz, #commandermtg for Commander notes).
- Adds "NZ Market — not financial advice" disclaimer and CollectorsCoast ticker link to every post.
