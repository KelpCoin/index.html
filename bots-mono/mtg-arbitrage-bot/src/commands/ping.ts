import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';

export const pingCommand: Command = {
  data: new SlashCommandBuilder().setName('ping').setDescription('Check bot latency.'),
  async execute(interaction) {
    await interaction.reply({ content: 'Pong!', ephemeral: true });
  }
};
