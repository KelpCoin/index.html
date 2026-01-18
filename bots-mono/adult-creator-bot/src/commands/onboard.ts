import {
  SlashCommandBuilder,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle
} from 'discord.js';
import type { Command } from '../types.js';

export const onboardCommand: Command = {
  data: new SlashCommandBuilder().setName('onboard').setDescription('Start the 18+ onboarding flow.'),
  async execute(interaction, context) {
    await context.db('onboarding_status')
      .insert({ guild_id: interaction.guildId, user_id: interaction.user.id })
      .onConflict(['guild_id', 'user_id'])
      .merge({ updated_at: new Date() });

    const embed = new EmbedBuilder()
      .setTitle('18+ Onboarding')
      .setDescription('Step 1: Confirm you are 18 or older to continue.');
    const buttons = new ActionRowBuilder<ButtonBuilder>().addComponents(
      new ButtonBuilder().setCustomId('onboard-confirm-18').setLabel('I am 18+').setStyle(ButtonStyle.Primary)
    );
    await interaction.reply({ embeds: [embed], components: [buttons], ephemeral: true });
  }
};
