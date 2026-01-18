import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';
import { checkDatabaseHealth } from 'shared-infra';

export const healthCommand: Command = {
  data: new SlashCommandBuilder().setName('health').setDescription('Admin health summary.'),
  adminOnly: true,
  async execute(interaction, context) {
    const dbHealthy = await checkDatabaseHealth(context.db);
    const jobRun = await context.db('job_runs').where({ job_name: 'alert-job' }).first();
    const embed = new EmbedBuilder()
      .setTitle('MTG Arbitrage Bot Health')
      .setColor(dbHealthy ? 0x2ecc71 : 0xe74c3c)
      .addFields(
        { name: 'Uptime (sec)', value: `${Math.floor(process.uptime())}`, inline: true },
        { name: 'Guilds', value: `${context.client.guilds.cache.size}`, inline: true },
        { name: 'DB Status', value: dbHealthy ? 'ok' : 'error', inline: true },
        {
          name: 'Last Alert Job Run',
          value: jobRun?.last_run_at ? new Date(jobRun.last_run_at).toISOString() : 'never',
          inline: false
        }
      );
    await interaction.reply({ embeds: [embed], ephemeral: true });
  }
};
