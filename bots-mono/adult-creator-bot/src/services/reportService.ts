import { ActionRowBuilder, ButtonBuilder, ButtonStyle } from 'discord.js';
import type { CommandContext } from '../types.js';
import { writeArtifact } from '../utils/artifacts.js';

export async function createReportThread(
  context: CommandContext,
  payload: {
    reportId: number;
    targetUserId: string;
    reporterId: string;
    reason: string;
    messageLink?: string;
    guildId: string;
  }
) {
  const config = await context.db('guild_config').where({ guild_id: payload.guildId }).first();
  if (!config?.reports_channel_id) {
    return;
  }
  const channel = await context.client.channels.fetch(config.reports_channel_id);
  if (!channel || !channel.isTextBased()) {
    return;
  }
  const buttons = new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId(`report-warn:${payload.reportId}`).setLabel('Warn').setStyle(ButtonStyle.Secondary),
    new ButtonBuilder()
      .setCustomId(`report-timeout:${payload.reportId}`)
      .setLabel('Timeout 24h')
      .setStyle(ButtonStyle.Secondary),
    new ButtonBuilder()
      .setCustomId(`report-remove-role:${payload.reportId}`)
      .setLabel('Remove Role')
      .setStyle(ButtonStyle.Secondary),
    new ButtonBuilder().setCustomId(`report-ban:${payload.reportId}`).setLabel('Ban').setStyle(ButtonStyle.Danger)
  );
  await channel.send({
    content: `Report #${payload.reportId} on <@${payload.targetUserId}> from <@${payload.reporterId}>\nReason: ${payload.reason}`,
    components: [buttons]
  });
  await writeArtifact('report', payload.reportId, payload);
}
