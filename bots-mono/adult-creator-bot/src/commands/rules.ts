import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';

const RULES_TEXT = [
  'Consent-first culture. Respect boundaries.',
  'No minors. Report concerns immediately.',
  'No harassment, coercion, or entitlement.',
  'Protect privacy and avoid sharing personal data.'
];

export const rulesCommand: Command = {
  data: new SlashCommandBuilder().setName('rules').setDescription('Post the rules embed.'),
  adminOnly: true,
  async execute(interaction, context) {
    const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
    if (!config?.rules_channel_id) {
      await interaction.reply({ content: 'Rules channel not configured.', ephemeral: true });
      return;
    }
    const channel = await interaction.client.channels.fetch(config.rules_channel_id);
    if (channel && channel.isTextBased()) {
      await channel.send({ content: RULES_TEXT.map((rule) => `• ${rule}`).join('\n') });
    }
    await interaction.reply({ content: 'Rules posted.', ephemeral: true });
  }
};
