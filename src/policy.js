const fs = require('fs');
const path = require('path');
const Logger = require('./logger');

const DEFAULT_POLICY_PATH = 'C:\\BrownEyeCortex\\Data\\Arbitrage_Policy.json';

const DEFAULT_POLICY = {
  preferred_marketplaces: [],
  banned_cards: [],
  risk_tolerance: 0.1,
  min_liquidity: 0,
  sell_window_days: 1,
};

function validateArray(value, fallback) {
  if (!Array.isArray(value)) return fallback;
  return value.filter((entry) => typeof entry === 'string' && entry.trim().length > 0);
}

function validateNumber(value, fallback, { min } = {}) {
  if (typeof value !== 'number' || Number.isNaN(value)) return fallback;
  if (min !== undefined && value < min) return fallback;
  return value;
}

function mergePolicy(partial = {}) {
  return {
    preferred_marketplaces: validateArray(partial.preferred_marketplaces, DEFAULT_POLICY.preferred_marketplaces),
    banned_cards: validateArray(partial.banned_cards, DEFAULT_POLICY.banned_cards),
    risk_tolerance: validateNumber(partial.risk_tolerance, DEFAULT_POLICY.risk_tolerance, { min: 0 }),
    min_liquidity: validateNumber(partial.min_liquidity, DEFAULT_POLICY.min_liquidity, { min: 0 }),
    sell_window_days: validateNumber(partial.sell_window_days, DEFAULT_POLICY.sell_window_days, { min: 1 }),
  };
}

function loadPolicy(policyPath = process.env.ARBITRAGE_POLICY_PATH || DEFAULT_POLICY_PATH, logger = new Logger(path.join(process.cwd(), 'logs', 'policy.log'))) {
  let parsed = {};
  try {
    const data = fs.readFileSync(policyPath, 'utf-8');
    parsed = JSON.parse(data);
    logger.info(`Loaded arbitrage policy from ${policyPath}`);
  } catch (error) {
    logger.warn(`Falling back to default policy because ${policyPath} could not be read (${error.message})`);
  }
  return mergePolicy(parsed);
}

function savePolicy(policyPath, policy, logger = new Logger(path.join(process.cwd(), 'logs', 'policy.log'))) {
  const normalizedPolicy = mergePolicy(policy);
  fs.mkdirSync(path.dirname(policyPath), { recursive: true });
  fs.writeFileSync(policyPath, JSON.stringify(normalizedPolicy, null, 2));
  logger.info(`Persisted arbitrage policy to ${policyPath}`);
  return normalizedPolicy;
}

module.exports = {
  DEFAULT_POLICY,
  DEFAULT_POLICY_PATH,
  loadPolicy,
  mergePolicy,
  savePolicy,
};
