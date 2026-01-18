import 'dotenv/config';
import { Client, Collection, GatewayIntentBits } from 'discord.js';
import { createDatabase, createLogger, loadEnv, migrateDatabase } from 'shared-infra';
import { loadConfig } from './config.js';
import { commands as commandList } from './commands/index.js';
import type { Command } from './types.js';
import { handleInteraction } from './interactionHandler.js';
import { scheduleJob } from './utils/scheduler.js';
import { runAlertJob } from './jobs/alertJob.js';
import { randomUUID } from 'node:crypto';

await loadEnv();
const config = loadConfig();
const logger = createLogger('mtg-arbitrage-bot');
const db = createDatabase({
  databaseUrl: config.databaseUrl,
  sqlitePath: config.sqlitePath,
  migrationsDir: new URL('../migrations', import.meta.url).pathname
});
await migrateDatabase(db);

const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const commands = new Collection<string, Command>();
for (const command of commandList) {
  commands.set(command.data.name, command);
}

client.once('ready', () => {
  logger.info('MTG arbitrage bot ready');
  scheduleJob(
    {
      name: 'alert-job',
      schedule: `*/${config.jobIntervalMinutes} * * * *`,
      jitterSeconds: 30,
      task: async () => {
        await runAlertJob({ client, db, marketApiKey: config.marketApiKey, logger });
      }
    },
    db
  );
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
