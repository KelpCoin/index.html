import { getEnv, getOptionalEnv } from 'shared-infra';

export type BotConfig = {
  token: string;
  clientId: string;
  guildId?: string;
  adminRoleIds: string[];
  databaseUrl?: string;
  sqlitePath?: string;
  jobIntervalMinutes: number;
  rateLimitWindowSeconds: number;
  rateLimitMax: number;
  marketApiKey?: string;
};

export function loadConfig(): BotConfig {
  const adminRoles = getOptionalEnv('ADMIN_ROLE_IDS', '')
    ?.split(',')
    .map((id) => id.trim())
    .filter(Boolean) ?? [];

  return {
    token: getEnv('DISCORD_TOKEN'),
    clientId: getEnv('DISCORD_CLIENT_ID'),
    guildId: getOptionalEnv('DISCORD_GUILD_ID'),
    adminRoleIds: adminRoles,
    databaseUrl: getOptionalEnv('DATABASE_URL'),
    sqlitePath: getOptionalEnv('SQLITE_PATH'),
    jobIntervalMinutes: Number(getOptionalEnv('JOB_INTERVAL_MINUTES', '30')),
    rateLimitWindowSeconds: Number(getOptionalEnv('RATE_LIMIT_WINDOW_SECONDS', '30')),
    rateLimitMax: Number(getOptionalEnv('RATE_LIMIT_MAX', '5')),
    marketApiKey: getOptionalEnv('MARKET_API_KEY')
  };
}
