#!/usr/bin/env bash
set -euo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20+ required." >&2
  exit 1
fi

npm install
npm run db:migrate
npm run deploy:commands
npm run start
