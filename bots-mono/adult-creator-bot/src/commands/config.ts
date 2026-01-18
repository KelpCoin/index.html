import { SlashCommandBuilder } from 'discord.js';
import type { Command } from '../types.js';

export const configCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('config')
    .setDescription('Admin configuration.')
    .addSubcommandGroup((group) =>
      group
        .setName('roles')
        .setDescription('Set role IDs.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set roles.')
            .addRoleOption((option) => option.setName('verified').setDescription('Verified 18+ role').setRequired(true))
            .addRoleOption((option) => option.setName('quarantine').setDescription('Quarantine role').setRequired(true))
            .addRoleOption((option) => option.setName('mod').setDescription('Moderator role').setRequired(true))
            .addRoleOption((option) => option.setName('creator').setDescription('Creator role').setRequired(true))
        )
    )
    .addSubcommandGroup((group) =>
      group
        .setName('channels')
        .setDescription('Set channel routing.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set channels.')
            .addChannelOption((option) => option.setName('rules').setDescription('Rules channel').setRequired(true))
            .addChannelOption((option) => option.setName('reports').setDescription('Reports channel').setRequired(true))
            .addChannelOption((option) => option.setName('modlog').setDescription('Mod log channel').setRequired(true))
            .addChannelOption((option) =>
              option.setName('creatorops').setDescription('Creator ops channel').setRequired(true)
            )
        )
    )
    .addSubcommandGroup((group) =>
      group
        .setName('toggles')
        .setDescription('Set onboarding toggles.')
        .addSubcommand((sub) =>
          sub
            .setName('set')
            .setDescription('Set toggles.')
            .addBooleanOption((option) =>
              option.setName('auto_dm_on_join').setDescription('Auto DM onboarding on join').setRequired(true)
            )
            .addBooleanOption((option) =>
              option.setName('auto_quarantine').setDescription('Auto quarantine on join').setRequired(true)
            )
        )
    ),
  adminOnly: true,
  async execute(interaction, context) {
    const group = interaction.options.getSubcommandGroup();
    if (group === 'roles') {
      const verified = interaction.options.getRole('verified', true);
      const quarantine = interaction.options.getRole('quarantine', true);
      const mod = interaction.options.getRole('mod', true);
      const creator = interaction.options.getRole('creator', true);
      await context.db('guild_config')
        .insert({
          guild_id: interaction.guildId,
          verified_role_id: verified.id,
          quarantine_role_id: quarantine.id,
          mod_role_id: mod.id,
          creator_role_id: creator.id
        })
        .onConflict('guild_id')
        .merge({
          verified_role_id: verified.id,
          quarantine_role_id: quarantine.id,
          mod_role_id: mod.id,
          creator_role_id: creator.id
        });
      await interaction.reply({ content: 'Roles updated.', ephemeral: true });
      return;
    }
    if (group === 'channels') {
      const rules = interaction.options.getChannel('rules', true);
      const reports = interaction.options.getChannel('reports', true);
      const modlog = interaction.options.getChannel('modlog', true);
      const creatorops = interaction.options.getChannel('creatorops', true);
      await context.db('guild_config')
        .insert({
          guild_id: interaction.guildId,
          rules_channel_id: rules.id,
          reports_channel_id: reports.id,
          modlog_channel_id: modlog.id,
          creatorops_channel_id: creatorops.id
        })
        .onConflict('guild_id')
        .merge({
          rules_channel_id: rules.id,
          reports_channel_id: reports.id,
          modlog_channel_id: modlog.id,
          creatorops_channel_id: creatorops.id
        });
      await interaction.reply({ content: 'Channels updated.', ephemeral: true });
      return;
    }
    if (group === 'toggles') {
      const autoDm = interaction.options.getBoolean('auto_dm_on_join', true);
      const autoQuarantine = interaction.options.getBoolean('auto_quarantine', true);
      await context.db('guild_config')
        .insert({ guild_id: interaction.guildId, auto_dm_on_join: autoDm, auto_quarantine: autoQuarantine })
        .onConflict('guild_id')
        .merge({ auto_dm_on_join: autoDm, auto_quarantine: autoQuarantine });
      await interaction.reply({ content: 'Toggles updated.', ephemeral: true });
    }
  }
};
