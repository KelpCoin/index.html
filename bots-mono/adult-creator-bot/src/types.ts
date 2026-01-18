import type { ChatInputCommandInteraction, Client, Collection, Interaction } from 'discord.js';
import type { Knex } from 'knex';
import type { Logger } from 'shared-infra';
import type { BotConfig } from './config.js';

export type CommandContext = {
  client: Client;
  db: Knex;
  logger: Logger;
  config: BotConfig;
  correlationId: string;
};

export type Command = {
  data: { name: string; description: string; toJSON(): unknown };
  adminOnly?: boolean;
  execute: (interaction: ChatInputCommandInteraction, context: CommandContext) => Promise<void>;
};

export type InteractionHandler = (interaction: Interaction, context: CommandContext) => Promise<void>;

export type CommandRegistry = Collection<string, Command>;
