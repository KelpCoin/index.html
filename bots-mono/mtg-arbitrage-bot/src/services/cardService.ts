import type { Knex } from 'knex';
import levenshtein from 'fast-levenshtein';
import { fetchScryfallCard } from '../adapters/scryfall.js';
import type { CardQuery } from '../adapters/types.js';

export type CanonicalCard = {
  id: number;
  name: string;
  set_code?: string;
  collector_number?: string;
  scryfall_id?: string;
  image_uri?: string;
  rarity?: string;
  type_line?: string;
};

export async function resolveCard(db: Knex, query: CardQuery): Promise<CanonicalCard | null> {
  if (query.scryfallId) {
    const card = await db('cards').where({ scryfall_id: query.scryfallId }).first();
    if (card) {
      return card;
    }
  }
  if (query.setCode && query.collectorNumber) {
    const card = await db('cards')
      .where({ set_code: query.setCode, collector_number: query.collectorNumber })
      .first();
    if (card) {
      return card;
    }
  }
  if (query.name) {
    const exact = await db('cards').whereRaw('lower(name) = lower(?)', [query.name]).first();
    if (exact) {
      return exact;
    }
    const candidates = await db('cards').select();
    const scored = candidates
      .map((card) => ({ card, score: levenshtein.get(card.name.toLowerCase(), query.name!.toLowerCase()) }))
      .sort((a, b) => a.score - b.score);
    if (scored[0] && scored[0].score <= 3) {
      return scored[0].card;
    }
  }
  const scryfall = await fetchScryfallCard(query);
  if (!scryfall) {
    return null;
  }
  const [id] = await db('cards').insert({
    name: scryfall.name,
    set_code: scryfall.set,
    collector_number: scryfall.collector_number,
    scryfall_id: scryfall.id,
    image_uri: scryfall.image_uris?.normal ?? scryfall.card_faces?.[0]?.image_uris?.normal,
    rarity: scryfall.rarity,
    type_line: scryfall.type_line
  });
  return db('cards').where({ id }).first();
}
