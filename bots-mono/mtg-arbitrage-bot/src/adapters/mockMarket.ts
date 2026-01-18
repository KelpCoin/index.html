import type { CardQuery, PriceQuote, PriceSourceAdapter } from './types.js';

const samplePrices: Record<string, number> = {
  'Sol Ring': 1.25,
  'Rhystic Study': 28.5,
  'Lightning Bolt': 1.1,
  'Cyclonic Rift': 32.75
};

export function createMockMarketAdapter(apiKey?: string): PriceSourceAdapter {
  return {
    name: 'MockMarket',
    async fetchPrice(query: CardQuery): Promise<PriceQuote | null> {
      if (!query.name) {
        return null;
      }
      const base = samplePrices[query.name] ?? 2.5;
      const variance = (Math.random() * 0.2 - 0.1) * base;
      const price = Math.max(0.1, base + variance);
      const info = apiKey ? 'authenticated' : 'public';
      return {
        source: `MockMarket-${info}`,
        price: Number(price.toFixed(2)),
        currency: 'USD',
        lastUpdated: new Date().toISOString()
      };
    }
  };
}
