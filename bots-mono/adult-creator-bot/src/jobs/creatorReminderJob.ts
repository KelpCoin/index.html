import type { Client, TextChannel } from 'discord.js';
import type { Knex } from 'knex';

export async function runCreatorReminders(params: { client: Client; db: Knex }) {
  const due = await params.db('creator_reminders')
    .where('scheduled_for', '<=', new Date())
    .andWhere({ status: 'scheduled' })
    .select();
  for (const reminder of due) {
    const config = await params.db('guild_config').where({ guild_id: reminder.guild_id }).first();
    if (!config?.creatorops_channel_id) {
      continue;
    }
    const channel = await params.client.channels.fetch(config.creatorops_channel_id);
    if (channel && channel.isTextBased()) {
      const roleMention = config.creator_role_id ? `<@&${config.creator_role_id}>` : '';
      await (channel as TextChannel).send({
        content: `${roleMention} Reminder from <@${reminder.creator_id}>: ${reminder.note ?? 'No note provided.'}`
      });
    }
    await params.db('creator_reminders').where({ id: reminder.id }).update({ status: 'sent' });
  }
}
