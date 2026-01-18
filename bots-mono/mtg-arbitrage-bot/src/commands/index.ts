import type { Command } from '../types.js';
import { pingCommand } from './ping.js';
import { healthCommand } from './health.js';
import { cardCommand } from './card.js';
import { priceCommand } from './price.js';
import { setCommand } from './set.js';
import { watchCommand } from './watch.js';
import { dealCommand } from './deal.js';
import { configCommand } from './config.js';
import { exportAlertsCommand } from './exportAlerts.js';

export const commands: Command[] = [
  pingCommand,
  healthCommand,
  cardCommand,
  priceCommand,
  setCommand,
  watchCommand,
  dealCommand,
  configCommand,
  exportAlertsCommand
];
