import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';

export const configCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('config')
    .setDescription('Admin configuration.')
    .addSubcommandGroup((group) =>
      group
        .setName('channels')
        .setDescription('Set channel routing.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set channel routing.')
            .addChannelOption((option) => option.setName('free').setDescription('Free alerts channel').setRequired(true))
            .addChannelOption((option) =>
              option.setName('premium').setDescription('Premium alerts channel').setRequired(true)
            )
            .addChannelOption((option) => option.setName('logs').setDescription('Logs channel').setRequired(false))
            .addRoleOption((option) => option.setName('deal_role').setDescription('Role to ping on approvals'))
        )
    )
    .addSubcommandGroup((group) =>
      group
        .setName('thresholds')
        .setDescription('Set alert thresholds.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set thresholds.')
            .addNumberOption((option) => option.setName('spike').setDescription('Spike percentage').setRequired(true))
            .addNumberOption((option) => option.setName('drop').setDescription('Drop percentage').setRequired(true))
            .addNumberOption((option) => option.setName('spread').setDescription('Spread percentage').setRequired(true))
            .addIntegerOption((option) =>
              option.setName('confidence_free').setDescription('Free confidence threshold').setRequired(true)
            )
            .addIntegerOption((option) =>
              option.setName('confidence_premium').setDescription('Premium confidence threshold').setRequired(true)
            )
        )
    )
    .addSubcommandGroup((group) =>
      group
        .setName('jobs')
        .setDescription('Set job intervals.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set job interval.')
            .addIntegerOption((option) =>
              option.setName('interval_minutes').setDescription('Interval minutes').setRequired(true)
            )
        )
    ),
  adminOnly: true,
  async execute(interaction, context) {
    const group = interaction.options.getSubcommandGroup();
    if (group === 'channels') {
      const free = interaction.options.getChannel('free', true);
      const premium = interaction.options.getChannel('premium', true);
      const logs = interaction.options.getChannel('logs');
      const dealRole = interaction.options.getRole('deal_role');
      await context.db('guild_config')
        .insert({
          guild_id: interaction.guildId,
          free_channel_id: free.id,
          premium_channel_id: premium.id,
          logs_channel_id: logs?.id ?? null,
          deal_role_id: dealRole?.id ?? null
        })
        .onConflict('guild_id')
        .merge({
          free_channel_id: free.id,
          premium_channel_id: premium.id,
          logs_channel_id: logs?.id ?? null,
          deal_role_id: dealRole?.id ?? null
        });
      await interaction.reply({ content: 'Channels updated.', ephemeral: true });
      return;
    }
    if (group === 'thresholds') {
      const spike = interaction.options.getNumber('spike', true);
      const drop = interaction.options.getNumber('drop', true);
      const spread = interaction.options.getNumber('spread', true);
      const confidenceFree = interaction.options.getInteger('confidence_free', true);
      const confidencePremium = interaction.options.getInteger('confidence_premium', true);
      await context.db('guild_config')
        .insert({
          guild_id: interaction.guildId,
          spike_threshold: spike,
          drop_threshold: drop,
          spread_threshold: spread,
          confidence_free: confidenceFree,
          confidence_premium: confidencePremium
        })
        .onConflict('guild_id')
        .merge({
          spike_threshold: spike,
          drop_threshold: drop,
          spread_threshold: spread,
          confidence_free: confidenceFree,
          confidence_premium: confidencePremium
        });
      await interaction.reply({ content: 'Thresholds updated.', ephemeral: true });
      return;
    }
    if (group === 'jobs') {
      const intervalMinutes = interaction.options.getInteger('interval_minutes', true);
      await context.db('guild_config')
        .insert({ guild_id: interaction.guildId, job_interval_minutes: intervalMinutes })
        .onConflict('guild_id')
        .merge({ job_interval_minutes: intervalMinutes });
      await interaction.reply({ content: 'Job interval updated.', ephemeral: true });
    }
  }
};
