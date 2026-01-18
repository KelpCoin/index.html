$ErrorActionPreference = "Stop"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error "Node.js 20+ required."
  exit 1
}

npm install
npm run db:migrate
npm run deploy:commands
npm run start
