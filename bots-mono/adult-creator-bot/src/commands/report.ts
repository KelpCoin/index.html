import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';
import { createReportThread } from '../services/reportService.js';

export const reportCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('report')
    .setDescription('Report a user to the moderators.')
    .addUserOption((option) => option.setName('user').setDescription('User to report').setRequired(true))
    .addStringOption((option) => option.setName('reason').setDescription('Reason').setRequired(true)),
  async execute(interaction, context) {
    const user = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason', true);
    const report = await context.db('reports').insert({
      guild_id: interaction.guildId,
      reporter_id: interaction.user.id,
      target_user_id: user.id,
      reason
    });
    await createReportThread(context, {
      reportId: Number(report[0]),
      targetUserId: user.id,
      reporterId: interaction.user.id,
      reason,
      guildId: interaction.guildId ?? ''
    });
    await interaction.reply({ content: 'Report submitted to moderators.', ephemeral: true });
  }
};
