import {
  SlashCommandBuilder,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  StringSelectMenuBuilder
} from 'discord.js';
import type { Command } from '../types.js';

export const watchCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('watch')
    .setDescription('Manage your MTG watchlist.')
    .addSubcommand((sub) =>
      sub
        .setName('add')
        .setDescription('Add a card to your watchlist.')
        .addStringOption((option) => option.setName('name').setDescription('Card name').setRequired(true))
        .addStringOption((option) => option.setName('set').setDescription('Set code'))
        .addStringOption((option) => option.setName('lang').setDescription('Language code'))
    )
    .addSubcommand((sub) =>
      sub
        .setName('remove')
        .setDescription('Remove a card from your watchlist.')
        .addStringOption((option) => option.setName('name').setDescription('Card name').setRequired(true))
    )
    .addSubcommand((sub) => sub.setName('list').setDescription('List your watchlist.'))
    .addSubcommand((sub) => sub.setName('import').setDescription('Import watchlist items from a list.')),
  async execute(interaction, context) {
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === 'add') {
      const name = interaction.options.getString('name', true);
      const setCode = interaction.options.getString('set');
      const lang = interaction.options.getString('lang');
      await context.db('watchlists').insert({
        guild_id: interaction.guildId,
        user_id: interaction.user.id,
        card_name: name,
        set_code: setCode ?? null,
        language: lang ?? null
      });
      await interaction.reply({ content: `Added **${name}** to your watchlist.`, ephemeral: true });
      return;
    }
    if (subcommand === 'remove') {
      const name = interaction.options.getString('name', true);
      await context.db('watchlists')
        .where({ guild_id: interaction.guildId, user_id: interaction.user.id })
        .andWhereRaw('lower(card_name) = lower(?)', [name])
        .del();
      await interaction.reply({ content: `Removed **${name}** from your watchlist.`, ephemeral: true });
      return;
    }
    if (subcommand === 'list') {
      const items = await context.db('watchlists')
        .where({ guild_id: interaction.guildId, user_id: interaction.user.id })
        .select();
      const list = items.length
        ? items.map((item) => `${item.card_name}${item.set_code ? ` (${item.set_code})` : ''}`).join('\n')
        : 'No watchlist items.';
      const menu = new StringSelectMenuBuilder()
        .setCustomId('watch-filter')
        .setPlaceholder('Filter watchlist')
        .addOptions([
          { label: 'All', value: 'all' },
          { label: 'With set codes', value: 'with-set' },
          { label: 'Without set codes', value: 'without-set' }
        ]);
      const row = new ActionRowBuilder<StringSelectMenuBuilder>().addComponents(menu);
      await interaction.reply({ content: list, components: [row], ephemeral: true });
      return;
    }
    if (subcommand === 'import') {
      const modal = new ModalBuilder().setCustomId('watch-import-modal').setTitle('Import Watchlist');
      const input = new TextInputBuilder()
        .setCustomId('watch-import-input')
        .setLabel('Paste card names, one per line')
        .setStyle(TextInputStyle.Paragraph)
        .setRequired(true);
      const row = new ActionRowBuilder<TextInputBuilder>().addComponents(input);
      modal.addComponents(row);
      await interaction.showModal(modal);
    }
  }
};

export function buildWatchImportPreview(names: string[]) {
  const preview = names.slice(0, 20).map((name) => `- ${name}`).join('\n');
  const buttonRow = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId('watch-import-confirm').setLabel('Confirm Import').setStyle(ButtonStyle.Success)
  );
  return { preview, buttonRow };
}
