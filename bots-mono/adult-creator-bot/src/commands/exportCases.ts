import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';
import fs from 'node:fs';
import path from 'node:path';

export const exportCasesCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('export')
    .setDescription('Export case summaries.')
    .addSubcommand((sub) =>
      sub
        .setName('cases')
        .setDescription('Export cases between dates.')
        .addStringOption((option) => option.setName('date_from').setDescription('YYYY-MM-DD').setRequired(true))
        .addStringOption((option) => option.setName('date_to').setDescription('YYYY-MM-DD').setRequired(true))
    ),
  adminOnly: true,
  async execute(interaction, context) {
    const from = interaction.options.getString('date_from', true);
    const to = interaction.options.getString('date_to', true);
    const fromDate = new Date(`${from}T00:00:00Z`);
    const toDate = new Date(`${to}T23:59:59Z`);
    const cases = await context
      .db('cases')
      .where({ guild_id: interaction.guildId })
      .andWhere('created_at', '>=', fromDate)
      .andWhere('created_at', '<=', toDate)
      .select();
    const folder = path.join(process.cwd(), 'data', 'artifacts');
    await fs.promises.mkdir(folder, { recursive: true });
    const filePath = path.join(folder, `cases_${from}_${to}.json`);
    await fs.promises.writeFile(filePath, JSON.stringify({ from, to, cases }, null, 2));
    const stats = await fs.promises.stat(filePath);
    const tooLarge = stats.size > 7_000_000;
    await interaction.reply({
      content: tooLarge
        ? `Case export ready at ${filePath}. File too large to attach.`
        : `Case export ready at ${filePath}.`,
      ephemeral: true
    });
  }
};
