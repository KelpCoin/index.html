import type { Client, TextChannel } from 'discord.js';
import type { Knex } from 'knex';

const DEFAULT_RULES = [
  'Consent and boundaries come first.',
  'No minors. Report concerns immediately.',
  'No harassment, coercion, or entitlement.',
  'Respect privacy and do not share personal info.'
];

export async function postRulesReminder(params: { client: Client; db: Knex }) {
  const configs = await params.db('guild_config').select();
  for (const config of configs) {
    if (!config.rules_channel_id) {
      continue;
    }
    const channel = await params.client.channels.fetch(config.rules_channel_id);
    if (channel && channel.isTextBased()) {
      await (channel as TextChannel).send({
        content: `Reminder:\n${DEFAULT_RULES.map((rule) => `• ${rule}`).join('\n')}`
      });
    }
  }
}
