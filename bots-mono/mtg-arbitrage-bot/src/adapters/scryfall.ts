import type { CardQuery, PriceQuote, PriceSourceAdapter } from './types.js';

const SCRYFALL_API = 'https://api.scryfall.com';

export async function fetchScryfallCard(query: CardQuery) {
  let url = '';
  if (query.scryfallId) {
    url = `${SCRYFALL_API}/cards/${query.scryfallId}`;
  } else if (query.setCode && query.collectorNumber) {
    url = `${SCRYFALL_API}/cards/${query.setCode}/${query.collectorNumber}`;
  } else if (query.name) {
    const params = new URLSearchParams({ q: `!"${query.name}"` });
    url = `${SCRYFALL_API}/cards/search?${params.toString()}`;
  } else {
    return null;
  }
  const res = await fetch(url, { headers: { 'User-Agent': 'mtg-arbitrage-bot' } });
  if (!res.ok) {
    return null;
  }
  const data = await res.json();
  if (data.object === 'list') {
    return data.data?.[0] ?? null;
  }
  return data;
}

export const scryfallAdapter: PriceSourceAdapter = {
  name: 'Scryfall',
  async fetchPrice(query: CardQuery): Promise<PriceQuote | null> {
    const card = await fetchScryfallCard(query);
    if (!card) {
      return null;
    }
    const usd = Number(card.prices?.usd ?? card.prices?.usd_foil ?? 0);
    if (!usd) {
      return null;
    }
    return {
      source: 'Scryfall',
      price: usd,
      currency: 'USD',
      lastUpdated: new Date().toISOString()
    };
  }
};
