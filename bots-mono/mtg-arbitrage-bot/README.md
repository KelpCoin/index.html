# MTG Arbitrage Bot

High-signal MTG arbitrage alerts with watchlists, deal desk approvals, and proof artifacts.

## Setup

1. Copy `.env.example` to `.env` and fill in values.
2. Install dependencies and run migrations.
3. Deploy slash commands.
4. Start the bot.

```bash
npm install
npm run db:migrate
npm run deploy:commands
npm run start
```

One-shot scripts:

```bash
./scripts/run.sh
# or
./scripts/run.ps1
```

## Verify

- Use `/ping` to check responsiveness.
- Use `/health` (admin only) to verify uptime, guild count, DB status, and last alert job run.

## Key Commands

- `/watch add|remove|list|import`
- `/card name:<string>`
- `/price name:<string>`
- `/set code:<string>`
- `/deal queue|approve|dismiss`
- `/config channels|thresholds|jobs`
- `/export alerts date:<YYYY-MM-DD>`

## Data

- SQLite default DB: `./data/app.sqlite`
- Logs: `./data/logs`
- Alert artifacts: `./data/artifacts/alerts/YYYY-MM-DD`

## Notes

- Scryfall is used for card identity and pricing data.
- MockMarket provides sample pricing without paid APIs.
