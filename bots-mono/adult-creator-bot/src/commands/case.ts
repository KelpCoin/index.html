import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';

export const caseCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('case')
    .setDescription('View moderation cases.')
    .addSubcommand((sub) =>
      sub
        .setName('view')
        .setDescription('View a case by ID.')
        .addIntegerOption((option) => option.setName('id').setDescription('Case ID').setRequired(true))
    )
    .addSubcommand((sub) => sub.setName('list').setDescription('List recent cases.')),
  adminOnly: true,
  async execute(interaction, context) {
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === 'view') {
      const id = interaction.options.getInteger('id', true);
      const record = await context.db('cases').where({ id, guild_id: interaction.guildId }).first();
      if (!record) {
        await interaction.reply({ content: 'Case not found.', ephemeral: true });
        return;
      }
      const embed = new EmbedBuilder()
        .setTitle(`Case #${record.id}`)
        .addFields(
          { name: 'Action', value: record.action, inline: true },
          { name: 'Moderator', value: `<@${record.moderator_id}>`, inline: true },
          { name: 'Details', value: record.details ?? 'n/a', inline: false }
        );
      await interaction.reply({ embeds: [embed], ephemeral: true });
      return;
    }
    if (subcommand === 'list') {
      const cases = await context.db('cases')
        .where({ guild_id: interaction.guildId })
        .orderBy('created_at', 'desc')
        .limit(10);
      await interaction.reply({
        content: cases.length
          ? cases.map((entry) => `#${entry.id} ${entry.action} by <@${entry.moderator_id}>`).join('\n')
          : 'No cases recorded.',
        ephemeral: true
      });
    }
  }
};
