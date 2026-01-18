import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  StringSelectMenuBuilder
} from 'discord.js';
import type { Interaction } from 'discord.js';
import type { CommandContext, CommandRegistry } from './types.js';
import { isAdmin } from './utils/permissions.js';
import { checkRateLimit } from './utils/rateLimit.js';
import { createReportThread } from './services/reportService.js';
import { writeArtifact } from './utils/artifacts.js';

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

  if (interaction.isMessageContextMenuCommand()) {
    if (interaction.commandName === 'Report Message') {
      const message = interaction.targetMessage;
      const report = await context.db('reports').insert({
        guild_id: interaction.guildId,
        reporter_id: interaction.user.id,
        target_user_id: message.author.id,
        reason: 'Reported message',
        message_id: message.id,
        channel_id: message.channelId
      });
      await createReportThread(context, {
        reportId: Number(report[0]),
        targetUserId: message.author.id,
        reporterId: interaction.user.id,
        reason: `Reported message: ${message.url}`,
        messageLink: message.url,
        guildId: interaction.guildId ?? ''
      });
      await interaction.reply({ content: 'Report submitted.', ephemeral: true });
    }
  }

  if (interaction.isButton()) {
    if (interaction.customId === 'onboard-confirm-18') {
      await context.db('onboarding_status')
        .where({ guild_id: interaction.guildId, user_id: interaction.user.id })
        .update({ confirmed_18: true, updated_at: new Date() });
      const next = new ActionRowBuilder<ButtonBuilder>().addComponents(
        new ButtonBuilder().setCustomId('onboard-agree-rules').setLabel('Agree to rules').setStyle(ButtonStyle.Primary)
      );
      await interaction.update({ content: 'Step 2: Agree to the rules.', components: [next] });
      await writeArtifact('onboarding', `${interaction.user.id}_confirmed`, {
        userId: interaction.user.id,
        guildId: interaction.guildId,
        step: 'confirmed_18'
      });
      return;
    }
    if (interaction.customId === 'onboard-agree-rules') {
      await context.db('onboarding_status')
        .where({ guild_id: interaction.guildId, user_id: interaction.user.id })
        .update({ agreed_rules: true, updated_at: new Date() });
      const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
      const options = [] as { label: string; value: string }[];
      if (config?.creator_role_id) {
        const role = interaction.guild?.roles.cache.get(config.creator_role_id);
        options.push({ label: role?.name ?? 'Creator', value: 'creator' });
      }
      options.push({ label: 'Community', value: 'community' });
      const menu = new StringSelectMenuBuilder()
        .setCustomId('onboard-role-select')
        .setPlaceholder('Select your primary role')
        .addOptions(options);
      const row = new ActionRowBuilder<StringSelectMenuBuilder>().addComponents(menu);
      await interaction.update({ content: 'Step 3: Select your role.', components: [row] });
      await writeArtifact('onboarding', `${interaction.user.id}_agreed`, {
        userId: interaction.user.id,
        guildId: interaction.guildId,
        step: 'agreed_rules'
      });
      return;
    }
    if (interaction.customId.startsWith('report-')) {
      const [action, reportId] = interaction.customId.split(':');
      if (action === 'report-ban') {
        const modal = new ModalBuilder().setCustomId(`report-ban-modal:${reportId}`).setTitle('Confirm Ban');
        const input = new TextInputBuilder()
          .setCustomId('ban-confirm')
          .setLabel('Type CONFIRM to ban')
          .setStyle(TextInputStyle.Short)
          .setRequired(true);
        const row = new ActionRowBuilder<TextInputBuilder>().addComponents(input);
        modal.addComponents(row);
        await interaction.showModal(modal);
        return;
      }
      await handleModerationAction(interaction, context, action, Number(reportId));
    }
  }

  if (interaction.isStringSelectMenu()) {
    if (interaction.customId === 'onboard-role-select') {
      const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
      const member = interaction.guild?.members.cache.get(interaction.user.id);
      if (!member) {
        await interaction.reply({ content: 'Unable to update roles.', ephemeral: true });
        return;
      }
      if (config?.quarantine_role_id) {
        await member.roles.remove(config.quarantine_role_id).catch(() => undefined);
      }
      if (config?.verified_role_id) {
        await member.roles.add(config.verified_role_id).catch(() => undefined);
      }
      if (interaction.values.includes('creator') && config?.creator_role_id) {
        await member.roles.add(config.creator_role_id).catch(() => undefined);
      }
      await context.db('onboarding_status')
        .where({ guild_id: interaction.guildId, user_id: interaction.user.id })
        .update({ completed: true, updated_at: new Date() });
      await interaction.update({ content: 'Onboarding complete. Welcome!', components: [] });
      await writeArtifact('onboarding', `${interaction.user.id}_completed`, {
        userId: interaction.user.id,
        guildId: interaction.guildId,
        step: 'completed',
        roles: interaction.values
      });
      return;
    }
  }

  if (interaction.isModalSubmit()) {
    if (interaction.customId.startsWith('report-ban-modal')) {
      const [, reportId] = interaction.customId.split(':');
      const confirm = interaction.fields.getTextInputValue('ban-confirm');
      if (confirm !== 'CONFIRM') {
        await interaction.reply({ content: 'Ban confirmation failed.', ephemeral: true });
        return;
      }
      await handleModerationAction(interaction, context, 'report-ban', Number(reportId));
    }
  }
}

async function handleModerationAction(
  interaction: Interaction,
  context: CommandContext,
  action: string,
  reportId: number
) {
  if (!interaction.guild) {
    return;
  }
  const report = await context.db('reports').where({ id: reportId, guild_id: interaction.guildId }).first();
  if (!report) {
    await interaction.reply({ content: 'Report not found.', ephemeral: true });
    return;
  }
  const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
  const member = await interaction.guild.members.fetch(report.target_user_id).catch(() => null);
  let actionLabel = action.replace('report-', '');
  if (action === 'report-warn') {
    actionLabel = 'warn';
  }
  if (action === 'report-timeout' && member) {
    await member.timeout(24 * 60 * 60 * 1000, 'Moderator timeout');
    actionLabel = 'timeout_24h';
  }
  if (action === 'report-remove-role' && member && config?.creator_role_id) {
    await member.roles.remove(config.creator_role_id);
    actionLabel = 'remove_role';
  }
  if (action === 'report-ban' && member) {
    await member.ban({ reason: 'Moderator ban' });
    actionLabel = 'ban';
  }
  const [caseId] = await context.db('cases').insert({
    guild_id: interaction.guildId,
    report_id: reportId,
    moderator_id: interaction.user.id,
    action: actionLabel,
    details: report.reason
  });
  await context.db('reports').where({ id: reportId }).update({ status: 'handled' });
  if (config?.modlog_channel_id) {
    const channel = await interaction.client.channels.fetch(config.modlog_channel_id);
    if (channel && channel.isTextBased()) {
      await channel.send({ content: `Case #${caseId}: ${actionLabel} for <@${report.target_user_id}>` });
    }
  }
  await writeArtifact('moderation', caseId, {
    caseId,
    action: actionLabel,
    moderatorId: interaction.user.id,
    reportId,
    targetUserId: report.target_user_id
  });
  if (interaction.isRepliable()) {
    if (interaction.deferred || interaction.replied) {
      await interaction.followUp({ content: `Action ${actionLabel} recorded.`, ephemeral: true });
    } else {
      await interaction.reply({ content: `Action ${actionLabel} recorded.`, ephemeral: true });
    }
  }
}
