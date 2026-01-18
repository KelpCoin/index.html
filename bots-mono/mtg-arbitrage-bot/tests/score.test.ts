import { describe, expect, it } from 'vitest';
import { computeScore } from '../src/services/priceService.js';

describe('computeScore', () => {
  it('returns higher score with more quotes', () => {
    const scoreOne = computeScore([{ source: 'a', price: 2, currency: 'USD', lastUpdated: new Date().toISOString() }], 0.1);
    const scoreTwo = computeScore(
      [
        { source: 'a', price: 2, currency: 'USD', lastUpdated: new Date().toISOString() },
        { source: 'b', price: 3, currency: 'USD', lastUpdated: new Date().toISOString() }
      ],
      0.1
    );
    expect(scoreTwo).toBeGreaterThan(scoreOne);
  });
});
