const path = require('path');
const QueueRunner = require('../src/queue_runner');
const LearnBot = require('../src/learn_bot');

const policyPath = path.join(process.cwd(), 'data', 'Arbitrage_Policy.json');
const queueRunner = new QueueRunner({ policyPath });
const learnBot = new LearnBot({ policyPath, queueRunner });

console.log('\nCurrent policy:', queueRunner.getPolicy());

const queue = [
  { cardId: 'RogueCurrent', marketplace: 'AquaExchange', liquidity: 1200, sellWindowDays: 3 },
  { cardId: 'BrightFin', marketplace: 'AquaExchange', liquidity: 900, sellWindowDays: 2 },
  { cardId: 'BrightFin', marketplace: 'Seagrass', liquidity: 1500, sellWindowDays: 6 },
  { cardId: 'BrightFin', marketplace: 'Seagrass', liquidity: 1500, sellWindowDays: 4 },
];

console.log('\nFiltered queue:', queueRunner.run(queue));

learnBot.adjustPolicy({
  preferred_marketplaces: ['AquaExchange', 'Seagrass', 'BrineBay'],
  risk_tolerance: 0.5,
  sell_window_days: 7,
});

console.log('\nUpdated policy:', queueRunner.getPolicy());
