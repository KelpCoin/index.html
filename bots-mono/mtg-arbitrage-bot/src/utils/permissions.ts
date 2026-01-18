import type { ChatInputCommandInteraction, GuildMember } from 'discord.js';

export function isAdmin(interaction: ChatInputCommandInteraction, adminRoleIds: string[]): boolean {
  if (!interaction.guild || !interaction.member) {
    return false;
  }
  const member = interaction.member as GuildMember;
  if (member.permissions.has('Administrator')) {
    return true;
  }
  if (adminRoleIds.length === 0) {
    return false;
  }
  return member.roles.cache.some((role) => adminRoleIds.includes(role.id));
}
