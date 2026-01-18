import { ActionRowBuilder, ButtonBuilder, ButtonStyle, EmbedBuilder } from 'discord.js';
import type { Interaction } from 'discord.js';
import type { CommandContext, CommandRegistry } from './types.js';
import { isAdmin } from './utils/permissions.js';
import { checkRateLimit } from './utils/rateLimit.js';
import { buildWatchImportPreview } from './commands/watch.js';
import { clearPendingImport, getPendingImport, setPendingImport } from './utils/watchImportStore.js';
import { getQueuePage, setQueuePage } from './utils/dealQueuePager.js';

export async function handleInteraction(
  interaction: Interaction,
  commands: CommandRegistry,
  context: CommandContext
) {
  if (interaction.isChatInputCommand()) {
    const command = commands.get(interaction.commandName);
    if (!command) {
      return;
    }
    if (command.adminOnly && !isAdmin(interaction, context.config.adminRoleIds)) {
      await interaction.reply({ content: 'Admin permissions required.', ephemeral: true });
      return;
    }
    const rateKey = `${interaction.user.id}:${interaction.commandName}`;
    const rate = checkRateLimit(rateKey, {
      windowSeconds: context.config.rateLimitWindowSeconds,
      max: context.config.rateLimitMax
    });
    if (!rate.allowed) {
      await interaction.reply({ content: 'Slow down and try again shortly.', ephemeral: true });
      return;
    }
    await command.execute(interaction, context);
    return;
  }

  if (interaction.isModalSubmit()) {
    if (interaction.customId === 'watch-import-modal') {
      const raw = interaction.fields.getTextInputValue('watch-import-input');
      const names = raw
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean);
      setPendingImport(interaction.user.id, names);
      const { preview, buttonRow } = buildWatchImportPreview(names);
      await interaction.reply({
        content: `Preview (${names.length} items):\n${preview}`,
        components: [buttonRow],
        ephemeral: true
      });
      return;
    }
  }

  if (interaction.isButton()) {
    if (interaction.customId === 'watch-import-confirm') {
      const names = getPendingImport(interaction.user.id) ?? [];
      if (!names.length) {
        await interaction.reply({ content: 'No pending import found.', ephemeral: true });
        return;
      }
      for (const name of names) {
        await context.db('watchlists').insert({
          guild_id: interaction.guildId,
          user_id: interaction.user.id,
          card_name: name
        });
      }
      clearPendingImport(interaction.user.id);
      await interaction.reply({ content: `Imported ${names.length} items.`, ephemeral: true });
      return;
    }
    if (interaction.customId.startsWith('deal-queue')) {
      const currentPage = getQueuePage(interaction.user.id);
      const nextPage = interaction.customId.endsWith('next') ? currentPage + 1 : Math.max(0, currentPage - 1);
      setQueuePage(interaction.user.id, nextPage);
      const deals = await context.db('deal_queue')
        .where({ guild_id: interaction.guildId, status: 'queued' })
        .orderBy('created_at', 'desc')
        .offset(nextPage * 5)
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
      await interaction.update({ embeds: [embed], components: [buttons] });
    }
  }

  if (interaction.isStringSelectMenu()) {
    if (interaction.customId === 'watch-filter') {
      const filter = interaction.values[0];
      let query = context.db('watchlists').where({ guild_id: interaction.guildId, user_id: interaction.user.id });
      if (filter === 'with-set') {
        query = query.whereNotNull('set_code');
      }
      if (filter === 'without-set') {
        query = query.whereNull('set_code');
      }
      const items = await query.select();
      const list = items.length
        ? items.map((item) => `${item.card_name}${item.set_code ? ` (${item.set_code})` : ''}`).join('\n')
        : 'No watchlist items.';
      await interaction.update({ content: list });
    }
  }
}
