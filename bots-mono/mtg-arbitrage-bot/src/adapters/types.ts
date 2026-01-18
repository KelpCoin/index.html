export type PriceQuote = {
  source: string;
  price: number;
  currency: string;
  lastUpdated: string;
};

export type CardQuery = {
  name?: string;
  scryfallId?: string;
  setCode?: string;
  collectorNumber?: string;
};

export interface PriceSourceAdapter {
  name: string;
  fetchPrice(query: CardQuery): Promise<PriceQuote | null>;
}
