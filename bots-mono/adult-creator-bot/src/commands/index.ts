import type { Command } from '../types.js';
import { pingCommand } from './ping.js';
import { healthCommand } from './health.js';
import { configCommand } from './config.js';
import { onboardCommand } from './onboard.js';
import { creatorCommand } from './creator.js';
import { reportCommand } from './report.js';
import { caseCommand } from './case.js';
import { rulesCommand } from './rules.js';
import { supportCommand } from './support.js';
import { exportCasesCommand } from './exportCases.js';
import { reportMessageCommand } from './reportMessage.js';

export const commands: Command[] = [
  pingCommand,
  healthCommand,
  configCommand,
  onboardCommand,
  creatorCommand,
  reportCommand,
  caseCommand,
  rulesCommand,
  supportCommand,
  exportCasesCommand
];

export const contextMenus = [reportMessageCommand];
