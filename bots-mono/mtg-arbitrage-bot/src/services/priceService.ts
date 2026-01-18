import type { PriceQuote, PriceSourceAdapter } from '../adapters/types.js';

export async function fetchQuotes(adapters: PriceSourceAdapter[], query: { name?: string; scryfallId?: string }) {
  const quotes = await Promise.all(adapters.map((adapter) => adapter.fetchPrice(query)));
  return quotes.filter((quote): quote is PriceQuote => Boolean(quote));
}

export function computeScore(quotes: PriceQuote[], volatility: number): number {
  if (quotes.length === 0) {
    return 0;
  }
  const prices = quotes.map((quote) => quote.price);
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const spread = max - min;
  const magnitude = spread / Math.max(min, 1);
  const agreement = Math.min(quotes.length / 2, 1);
  const recency = quotes.every((quote) => Date.now() - new Date(quote.lastUpdated).getTime() < 1000 * 60 * 60)
    ? 1
    : 0.5;
  const score = Math.round((agreement * 40 + magnitude * 40 + recency * 10 + (1 - volatility) * 10) * 2.5);
  return Math.min(100, Math.max(0, score));
}
