import { REST, Routes } from 'discord.js';
import { loadEnv } from 'shared-infra';
import { loadConfig } from '../src/config.js';
import { commands, contextMenus } from '../src/commands/index.js';

await loadEnv();
const config = loadConfig();
const rest = new REST({ version: '10' }).setToken(config.token);
const body = [...commands.map((command) => command.data.toJSON()), ...contextMenus.map((command) => command.toJSON())];

if (config.guildId) {
  await rest.put(Routes.applicationGuildCommands(config.clientId, config.guildId), { body });
  console.log('Guild commands deployed.');
} else {
  await rest.put(Routes.applicationCommands(config.clientId), { body });
  console.log('Global commands deployed.');
}
