import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';

export const setCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('set')
    .setDescription('Lookup a set by code.')
    .addStringOption((option) => option.setName('code').setDescription('Set code').setRequired(true)),
  async execute(interaction) {
    const code = interaction.options.getString('code', true).toLowerCase();
    const res = await fetch(`https://api.scryfall.com/sets/${code}`);
    if (!res.ok) {
      await interaction.reply({ content: 'Set not found.', ephemeral: true });
      return;
    }
    const data = await res.json();
    const embed = new EmbedBuilder()
      .setTitle(`${data.name} (${data.code})`)
      .setDescription(data.set_type)
      .addFields(
        { name: 'Card Count', value: `${data.card_count}`, inline: true },
        { name: 'Release Date', value: data.released_at ?? 'n/a', inline: true }
      )
      .setThumbnail(data.icon_svg_uri ?? null);
    await interaction.reply({ embeds: [embed], ephemeral: true });
  }
};
