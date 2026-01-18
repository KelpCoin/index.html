# Adult Creator Community Bot

Consent-first 18+ community operations bot with onboarding, reporting, creator ops, and audit logs. It does not generate explicit content.

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
- Use `/health` (admin only) to verify uptime, guild count, DB status, and last rules reminder.

## Key Commands

- `/onboard start`
- `/config roles|channels|toggles`
- `/creator post-template|schedule-reminder|content-tags|link-hub`
- `/report user:<user> reason:<string>`
- Context menu: **Report Message**
- `/case view|list`
- `/rules post`
- `/support set|post`
- `/export cases date_from:<YYYY-MM-DD> date_to:<YYYY-MM-DD>`

## Data

- SQLite default DB: `./data/app.sqlite`
- Logs: `./data/logs`
- Artifacts: `./data/artifacts`

## Notes

- Safety keyword alerts are configured with `KEYWORD_ALERTS`.
- Reminders post to the creator ops channel on schedule.
