import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';
import fs from 'node:fs';
import path from 'node:path';
import archiver from 'archiver';

export const exportAlertsCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('export')
    .setDescription('Export alert artifacts.')
    .addSubcommand((sub) =>
      sub
        .setName('alerts')
        .setDescription('Export alerts for a date.')
        .addStringOption((option) => option.setName('date').setDescription('YYYY-MM-DD').setRequired(true))
    ),
  adminOnly: true,
  async execute(interaction) {
    const date = interaction.options.getString('date', true);
    const baseDir = path.join(process.cwd(), 'data', 'artifacts', 'alerts', date);
    if (!fs.existsSync(baseDir)) {
      await interaction.reply({ content: 'No artifacts found for that date.', ephemeral: true });
      return;
    }
    const zipPath = path.join(process.cwd(), 'data', 'artifacts', `alerts_${date}.zip`);
    await new Promise<void>((resolve, reject) => {
      const output = fs.createWriteStream(zipPath);
      const archive = archiver('zip');
      output.on('close', () => resolve());
      archive.on('error', (err) => reject(err));
      archive.pipe(output);
      archive.directory(baseDir, false);
      archive.finalize();
    });
    const stats = await fs.promises.stat(zipPath);
    const tooLarge = stats.size > 7_000_000;
    await interaction.reply({
      content: tooLarge
        ? `Archive ready at ${zipPath}. File too large to attach.`
        : `Archive ready at ${zipPath}.`,
      ephemeral: true
    });
  }
};
