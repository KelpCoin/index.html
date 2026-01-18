import 'dotenv/config';
import { Client, Collection, GatewayIntentBits, Partials } from 'discord.js';
import { createDatabase, createLogger, loadEnv, migrateDatabase } from 'shared-infra';
import { loadConfig } from './config.js';
import { commands as commandList } from './commands/index.js';
import type { Command } from './types.js';
import { handleInteraction } from './interactionHandler.js';
import { scheduleJob } from './utils/scheduler.js';
import { postRulesReminder } from './jobs/rulesReminderJob.js';
import { runCreatorReminders } from './jobs/creatorReminderJob.js';
import { randomUUID } from 'node:crypto';

await loadEnv();
const config = loadConfig();
const logger = createLogger('adult-creator-bot');
const db = createDatabase({
  databaseUrl: config.databaseUrl,
  sqlitePath: config.sqlitePath,
  migrationsDir: new URL('../migrations', import.meta.url).pathname
});
await migrateDatabase(db);

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers, GatewayIntentBits.GuildMessages],
  partials: [Partials.Channel]
});
const commands = new Collection<string, Command>();
for (const command of commandList) {
  commands.set(command.data.name, command);
}

client.once('ready', () => {
  logger.info('Adult creator bot ready');
  scheduleJob({ name: 'rules-reminder', schedule: '0 9 * * *', jitterSeconds: 60, task: () => postRulesReminder({ client, db }) }, db);
  scheduleJob({ name: 'creator-reminders', schedule: '*/5 * * * *', jitterSeconds: 30, task: () => runCreatorReminders({ client, db }) }, db);
});

client.on('interactionCreate', async (interaction) => {
  const correlationId = randomUUID();
  const requestLogger = logger.child({ correlationId });
  try {
    await handleInteraction(interaction, commands, {
      client,
      db,
      logger: requestLogger,
      config,
      correlationId
    });
  } catch (error) {
    requestLogger.error('Interaction failed', { error });
    if (interaction.isRepliable()) {
      const response = { content: 'An error occurred handling that request.', ephemeral: true };
      if (interaction.deferred || interaction.replied) {
        await interaction.followUp(response);
      } else {
        await interaction.reply(response);
      }
    }
  }
});

client.on('guildMemberAdd', async (member) => {
  const configRow = await db('guild_config').where({ guild_id: member.guild.id }).first();
  if (!configRow) {
    return;
  }
  if (configRow.auto_quarantine && configRow.quarantine_role_id) {
    await member.roles.add(configRow.quarantine_role_id).catch(() => undefined);
  }
  if (configRow.auto_dm_on_join) {
    await member.send('Welcome. Use /onboard start to begin the 18+ onboarding flow.').catch(() => undefined);
  }
});

client.on('messageCreate', async (message) => {
  if (!message.guild || message.author.bot) {
    return;
  }
  const configRow = await db('guild_config').where({ guild_id: message.guild.id }).first();
  if (!configRow?.reports_channel_id) {
    return;
  }
  const keywords = (process.env.KEYWORD_ALERTS ?? 'minor,underage,dox').split(',').map((word) => word.trim());
  const content = message.content.toLowerCase();
  const hit = keywords.find((word) => word && content.includes(word));
  if (hit) {
    const channel = await message.client.channels.fetch(configRow.reports_channel_id);
    if (channel && channel.isTextBased()) {
      await channel.send({
        content: `Keyword alert: "${hit}" in ${message.url} from <@${message.author.id}>.`
      });
    }
  }
});

process.on('SIGINT', async () => {
  logger.info('Shutting down...');
  await client.destroy();
  await db.destroy();
  process.exit(0);
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error });
});

process.on('unhandledRejection', (error) => {
  logger.error('Unhandled rejection', { error });
});

await client.login(config.token);
