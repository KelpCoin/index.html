import { ContextMenuCommandBuilder, ApplicationCommandType } from 'discord.js';

export const reportMessageCommand = new ContextMenuCommandBuilder()
  .setName('Report Message')
  .setType(ApplicationCommandType.Message);
