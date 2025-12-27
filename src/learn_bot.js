const path = require('path');
const QueueRunner = require('./queue_runner');
const Logger = require('./logger');
const { savePolicy, loadPolicy, mergePolicy, DEFAULT_POLICY_PATH } = require('./policy');

class LearnBot {
  constructor({ policyPath, logger, queueRunner } = {}) {
    this.policyPath = policyPath || process.env.ARBITRAGE_POLICY_PATH || DEFAULT_POLICY_PATH;
    this.logger = logger || new Logger(path.join(process.cwd(), 'logs', 'learn_bot.log'));
    this.queueRunner = queueRunner || new QueueRunner({ policyPath: this.policyPath, logger: this.logger });
  }

  adjustPolicy(updates = {}) {
    const allowedKeys = new Set([
      'preferred_marketplaces',
      'banned_cards',
      'risk_tolerance',
      'min_liquidity',
      'sell_window_days',
    ]);

    const currentPolicy = loadPolicy(this.policyPath, this.logger);
    const nextPolicy = mergePolicy(currentPolicy);

    Object.entries(updates).forEach(([key, value]) => {
      if (!allowedKeys.has(key)) {
        this.logger.warn(`Ignoring unsupported policy field ${key}.`);
        return;
      }

      const proposedPolicy = mergePolicy({ ...nextPolicy, [key]: value });
      const previousValue = nextPolicy[key];
      const newValue = proposedPolicy[key];

      if (JSON.stringify(previousValue) === JSON.stringify(newValue)) {
        this.logger.info(`No change detected for ${key}; leaving existing value.`);
        return;
      }

      nextPolicy[key] = newValue;
      this.logger.info(`Updated policy field ${key} from ${JSON.stringify(previousValue)} to ${JSON.stringify(newValue)}.`);
    });

    const persisted = savePolicy(this.policyPath, nextPolicy, this.logger);
    this.queueRunner.policy = persisted;
    return persisted;
  }
}

module.exports = LearnBot;
