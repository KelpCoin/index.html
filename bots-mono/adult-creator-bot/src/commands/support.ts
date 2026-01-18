import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';

const DISCLAIMER = 'Support never buys entitlement, access, or rule exceptions.';

export const supportCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('support')
    .setDescription('Manage support messages.')
    .addSubcommand((sub) =>
      sub
        .setName('set')
        .setDescription('Set the support message.')
        .addStringOption((option) => option.setName('link').setDescription('Support link').setRequired(true))
        .addStringOption((option) => option.setName('message').setDescription('Message body').setRequired(true))
    )
    .addSubcommand((sub) => sub.setName('post').setDescription('Post the support message.')),
  adminOnly: true,
  async execute(interaction, context) {
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === 'set') {
      const link = interaction.options.getString('link', true);
      const message = interaction.options.getString('message', true);
      await context.db('support_message')
        .insert({ guild_id: interaction.guildId, link, message })
        .onConflict('guild_id')
        .merge({ link, message, updated_at: new Date() });
      await interaction.reply({ content: 'Support message updated.', ephemeral: true });
      return;
    }
    if (subcommand === 'post') {
      const config = await context.db('support_message').where({ guild_id: interaction.guildId }).first();
      if (!config) {
        await interaction.reply({ content: 'Support message not configured.', ephemeral: true });
        return;
      }
      await interaction.reply({ content: `${config.message}\n${config.link}\n${DISCLAIMER}`, ephemeral: false });
    }
  }
};
