const path = require('path');
const Logger = require('./logger');
const { loadPolicy, DEFAULT_POLICY_PATH } = require('./policy');

class QueueRunner {
  constructor({ policyPath, logger } = {}) {
    this.policyPath = policyPath || process.env.ARBITRAGE_POLICY_PATH || DEFAULT_POLICY_PATH;
    this.logger = logger || new Logger(path.join(process.cwd(), 'logs', 'queue_runner.log'));
    this.policy = loadPolicy(this.policyPath, this.logger);
  }

  refreshPolicy() {
    this.policy = loadPolicy(this.policyPath, this.logger);
    return this.policy;
  }

  getPolicy() {
    return { ...this.policy };
  }

  run(queue = []) {
    if (!Array.isArray(queue)) {
      this.logger.warn('QueueRunner.run called with a non-array queue; returning empty list.');
      return [];
    }

    return queue.filter((job) => this._shouldProcess(job));
  }

  _shouldProcess(job) {
    if (!job || typeof job !== 'object') {
      this.logger.warn('Encountered invalid job; skipping.');
      return false;
    }

    if (job.cardId && this.policy.banned_cards.includes(job.cardId)) {
      this.logger.info(`Skipping job for banned card ${job.cardId}.`);
      return false;
    }

    if (job.marketplace && this.policy.preferred_marketplaces.length > 0 && !this.policy.preferred_marketplaces.includes(job.marketplace)) {
      this.logger.info(`Skipping job for marketplace ${job.marketplace} because it is not in preferred list.`);
      return false;
    }

    if (typeof job.liquidity === 'number' && job.liquidity < this.policy.min_liquidity) {
      this.logger.info(`Skipping job ${job.cardId || 'unknown'} due to insufficient liquidity (${job.liquidity}).`);
      return false;
    }

    if (typeof job.sellWindowDays === 'number' && job.sellWindowDays > this.policy.sell_window_days) {
      this.logger.info(`Skipping job ${job.cardId || 'unknown'} due to sell window (${job.sellWindowDays} days) beyond policy limit.`);
      return false;
    }

    return true;
  }
}

module.exports = QueueRunner;
