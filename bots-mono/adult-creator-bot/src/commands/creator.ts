import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import type { Command } from '../types.js';
import { isAdmin } from '../utils/permissions.js';

const templates: Record<string, string> = {
  drop: 'New content drop is live. Please respect boundaries and review the rules before engaging.',
  teaser: 'Teaser time. Full details will follow soon. Please keep interactions respectful.',
  qna: 'Q&A window is open. Ask thoughtful questions and honor consent-based boundaries.',
  live: 'Going live soon. Bring supportive vibes and keep chat respectful.',
  'behind-the-scenes': 'Sharing behind-the-scenes updates. Please keep feedback constructive.'
};

export const creatorCommand: Command = {
  data: new SlashCommandBuilder()
    .setName('creator')
    .setDescription('Creator operations tools.')
    .addSubcommand((sub) =>
      sub
        .setName('post-template')
        .setDescription('Post a non-explicit template message.')
        .addStringOption((option) =>
          option
            .setName('type')
            .setDescription('Template type')
            .setRequired(true)
            .addChoices(
              { name: 'Drop', value: 'drop' },
              { name: 'Teaser', value: 'teaser' },
              { name: 'Q&A', value: 'qna' },
              { name: 'Live', value: 'live' },
              { name: 'Behind the scenes', value: 'behind-the-scenes' }
            )
        )
    )
    .addSubcommand((sub) =>
      sub
        .setName('schedule-reminder')
        .setDescription('Schedule a creator ops reminder.')
        .addStringOption((option) =>
          option.setName('when').setDescription('ISO time, e.g. 2025-01-20T15:00:00Z').setRequired(true)
        )
        .addStringOption((option) => option.setName('note').setDescription('Reminder note').setRequired(true))
    )
    .addSubcommand((sub) =>
      sub
        .setName('content-tags')
        .setDescription('Manage allowed content tags.')
        .addStringOption((option) =>
          option
            .setName('action')
            .setDescription('add or remove')
            .setRequired(true)
            .addChoices(
              { name: 'Add', value: 'add' },
              { name: 'Remove', value: 'remove' },
              { name: 'List', value: 'list' }
            )
        )
        .addStringOption((option) => option.setName('tag').setDescription('Tag value'))
    )
    .addSubcommand((sub) =>
      sub
        .setName('link-hub')
        .setDescription('Set or view a creator link hub.')
        .addStringOption((option) =>
          option
            .setName('action')
            .setDescription('set or view')
            .setRequired(true)
            .addChoices(
              { name: 'Set', value: 'set' },
              { name: 'View', value: 'view' }
            )
        )
        .addUserOption((option) => option.setName('user').setDescription('User to view'))
        .addStringOption((option) => option.setName('bio').setDescription('Safe bio'))
        .addStringOption((option) => option.setName('links').setDescription('Links, comma separated'))
    ),
  async execute(interaction, context) {
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === 'post-template') {
      const type = interaction.options.getString('type', true);
      const message = templates[type];
      const config = await context.db('guild_config').where({ guild_id: interaction.guildId }).first();
      if (!config?.creatorops_channel_id) {
        await interaction.reply({ content: 'Creator ops channel not configured.', ephemeral: true });
        return;
      }
      const channel = await interaction.client.channels.fetch(config.creatorops_channel_id);
      if (channel && channel.isTextBased()) {
        await channel.send({ content: message });
      }
      await interaction.reply({ content: 'Template posted.', ephemeral: true });
      return;
    }
    if (subcommand === 'schedule-reminder') {
      const when = interaction.options.getString('when', true);
      const note = interaction.options.getString('note', true);
      const scheduledFor = new Date(when);
      if (Number.isNaN(scheduledFor.getTime())) {
        await interaction.reply({ content: 'Invalid time format.', ephemeral: true });
        return;
      }
      await context.db('creator_reminders').insert({
        guild_id: interaction.guildId,
        creator_id: interaction.user.id,
        scheduled_for: scheduledFor,
        note
      });
      await interaction.reply({ content: `Reminder scheduled for ${scheduledFor.toISOString()}.`, ephemeral: true });
      return;
    }
    if (subcommand === 'content-tags') {
      if (!isAdmin(interaction, context.config.adminRoleIds)) {
        await interaction.reply({ content: 'Admin permissions required.', ephemeral: true });
        return;
      }
      const action = interaction.options.getString('action', true);
      if (action === 'list') {
        const tags = await context.db('content_tags').where({ guild_id: interaction.guildId }).select();
        await interaction.reply({
          content: tags.length ? tags.map((tag) => `• ${tag.tag}`).join('\n') : 'No tags set.',
          ephemeral: true
        });
        return;
      }
      const tag = interaction.options.getString('tag');
      if (!tag) {
        await interaction.reply({ content: 'Tag value required.', ephemeral: true });
        return;
      }
      if (action === 'add') {
        await context.db('content_tags').insert({ guild_id: interaction.guildId, tag });
        await interaction.reply({ content: `Added tag: ${tag}`, ephemeral: true });
        return;
      }
      if (action === 'remove') {
        await context.db('content_tags').where({ guild_id: interaction.guildId, tag }).del();
        await interaction.reply({ content: `Removed tag: ${tag}`, ephemeral: true });
        return;
      }
    }
    if (subcommand === 'link-hub') {
      const action = interaction.options.getString('action', true);
      if (action === 'set') {
        const bio = interaction.options.getString('bio') ?? '';
        const links = interaction.options.getString('links') ?? '';
        await context.db('link_hub')
          .insert({ guild_id: interaction.guildId, user_id: interaction.user.id, bio, links })
          .onConflict(['guild_id', 'user_id'])
          .merge({ bio, links, updated_at: new Date() });
        await interaction.reply({ content: 'Link hub updated.', ephemeral: true });
        return;
      }
      if (action === 'view') {
        const user = interaction.options.getUser('user') ?? interaction.user;
        const record = await context.db('link_hub').where({ guild_id: interaction.guildId, user_id: user.id }).first();
        if (!record) {
          await interaction.reply({ content: 'No link hub found.', ephemeral: true });
          return;
        }
        const embed = new EmbedBuilder()
          .setTitle(`${user.username}'s Link Hub`)
          .setDescription(record.bio || 'No bio set.')
          .addFields({ name: 'Links', value: record.links || 'No links set.' });
        await interaction.reply({ embeds: [embed], ephemeral: true });
      }
    }
  }
};
