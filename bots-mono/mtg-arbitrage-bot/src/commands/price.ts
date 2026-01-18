import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';
import { resolveCard } from '../services/cardService.js';
import { fetchQuotes } from '../services/priceService.js';
import { createMockMarketAdapter } from '../adapters/mockMarket.js';
import { scryfallAdapter } from '../adapters/scryfall.js';

export const priceCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('price')
    .setDescription('Get a price table for a card.')
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
      .setTitle(`Price table: ${card.name}`)
      .setColor(0x3498db)
      .setDescription(
        quotes.length
          ? quotes.map((quote) => `**${quote.source}**: $${quote.price} (${quote.lastUpdated})`).join('\n')
          : 'No price quotes available.'
      );
    await interaction.reply({ embeds: [embed], ephemeral: true });
  }
};
