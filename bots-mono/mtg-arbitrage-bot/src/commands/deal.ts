import {
  SlashCommandBuilder,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle
} from 'discord.js';
import type { Command } from '../types.js';

export const dealCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('deal')
    .setDescription('Manage deal desk queue.')
    .addSubcommand((sub) => sub.setName('queue').setDescription('View queued deals.'))
    .addSubcommand((sub) =>
      sub
        .setName('approve')
        .setDescription('Approve a queued deal.')
        .addIntegerOption((option) => option.setName('id').setDescription('Deal ID').setRequired(true))
    )
    .addSubcommand((sub) =>
      sub
        .setName('dismiss')
        .setDescription('Dismiss a queued deal.')
        .addIntegerOption((option) => option.setName('id').setDescription('Deal ID').setRequired(true))
        .addStringOption((option) => option.setName('reason').setDescription('Dismiss reason').setRequired(true))
    ),
  adminOnly: true,
  async execute(interaction, context) {
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === 'queue') {
      const deals = await context.db('deal_queue')
        .where({ guild_id: interaction.guildId, status: 'queued' })
        .orderBy('created_at', 'desc')
        .limit(5);
      const embed = new EmbedBuilder()
        .setTitle('Deal Queue')
        .setDescription(
          deals.length
            ? deals.map((deal) => `#${deal.id} **${deal.card_name}** (diff $${deal.price_diff})`).join('\n')
            : 'No queued deals.'
        );
      const buttons = new ActionRowBuilder<ButtonBuilder>().addComponents(
        new ButtonBuilder().setCustomId('deal-queue-prev').setLabel('Prev').setStyle(ButtonStyle.Secondary),
        new ButtonBuilder().setCustomId('deal-queue-next').setLabel('Next').setStyle(ButtonStyle.Secondary)
      );
      await interaction.reply({ embeds: [embed], components: [buttons], ephemeral: true });
      return;
    }
    if (subcommand === 'approve') {
      const id = interaction.options.getInteger('id', true);
      const deal = await context.db('deal_queue').where({ id, guild_id: interaction.guildId }).first();
      if (!deal) {
        await interaction.reply({ content: 'Deal not found.', ephemeral: true });
        return;
      }
      const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
      await context.db('deal_queue')
        .where({ id })
        .update({ status: 'approved', moderator_id: interaction.user.id, updated_at: new Date() });
      if (config?.premium_channel_id) {
        const channel = await interaction.client.channels.fetch(config.premium_channel_id);
        if (channel && channel.isTextBased()) {
          const roleMention = config.deal_role_id ? `<@&${config.deal_role_id}>` : '';
          await channel.send({
            content: `${roleMention} Approved deal #${deal.id}: **${deal.card_name}** (diff $${deal.price_diff})`
          });
        }
      }
      await interaction.reply({ content: `Deal #${id} approved.`, ephemeral: true });
      return;
    }
    if (subcommand === 'dismiss') {
      const id = interaction.options.getInteger('id', true);
      const reason = interaction.options.getString('reason', true);
      const deal = await context.db('deal_queue').where({ id, guild_id: interaction.guildId }).first();
      if (!deal) {
        await interaction.reply({ content: 'Deal not found.', ephemeral: true });
        return;
      }
      await context.db('deal_queue')
        .where({ id })
        .update({ status: 'dismissed', moderator_id: interaction.user.id, reason, updated_at: new Date() });
      await interaction.reply({ content: `Deal #${id} dismissed.`, ephemeral: true });
    }
  }
};
