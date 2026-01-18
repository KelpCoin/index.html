import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';
import { resolveCard } from '../services/cardService.js';
import { fetchQuotes } from '../services/priceService.js';
import { createMockMarketAdapter } from '../adapters/mockMarket.js';
import { scryfallAdapter } from '../adapters/scryfall.js';

export const cardCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('card')
    .setDescription('Lookup a card and show details.')
    .addStringOption((option) => option.setName('name').setDescription('Card name').setRequired(true)),
  async execute(interaction, context) {
    const name = interaction.options.getString('name', true);
    const card = await resolveCard(context.db, { name });
    if (!card) {
      await interaction.reply({ content: 'Card not found.', ephemeral: true });
      return;
    }
    const quotes = await fetchQuotes([scryfallAdapter, createMockMarketAdapter(context.config.marketApiKey)], {
      name: card.name,
      scryfallId: card.scryfall_id
    });
    const embed = new EmbedBuilder()
      .setTitle(card.name)
      .setDescription(`${card.type_line ?? ''} (${card.rarity ?? 'unknown'})`)
      .setThumbnail(card.image_uri ?? null)
      .addFields(
        { name: 'Set', value: card.set_code ?? 'n/a', inline: true },
        { name: 'Collector #', value: card.collector_number ?? 'n/a', inline: true },
        {
          name: 'Last Known Prices',
          value: quotes.length ? quotes.map((quote) => `${quote.source}: $${quote.price}`).join('\n') : 'No data',
          inline: false
        }
      );
    await interaction.reply({ embeds: [embed], ephemeral: true });
  }
};
