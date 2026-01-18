import { getEnv, getOptionalEnv } from 'shared-infra';

export type BotConfig = {
  token: string;
  clientId: string;
  guildId?: string;
  adminRoleIds: string[];
  databaseUrl?: string;
  sqlitePath?: string;
  rateLimitWindowSeconds: number;
  rateLimitMax: number;
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
    rateLimitWindowSeconds: Number(getOptionalEnv('RATE_LIMIT_WINDOW_SECONDS', '30')),
    rateLimitMax: Number(getOptionalEnv('RATE_LIMIT_MAX', '5'))
  };
}
