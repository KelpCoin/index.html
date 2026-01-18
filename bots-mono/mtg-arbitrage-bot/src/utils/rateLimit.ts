export type RateLimitConfig = {
  windowSeconds: number;
  max: number;
};

type RateEntry = {
  count: number;
  resetAt: number;
};

const rateMap = new Map<string, RateEntry>();

export function checkRateLimit(key: string, config: RateLimitConfig): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const current = rateMap.get(key);
  if (!current || current.resetAt <= now) {
    const entry = { count: 1, resetAt: now + config.windowSeconds * 1000 };
    rateMap.set(key, entry);
    return { allowed: true, remaining: config.max - 1 };
  }
  if (current.count >= config.max) {
    return { allowed: false, remaining: 0 };
  }
  current.count += 1;
  rateMap.set(key, current);
  return { allowed: true, remaining: config.max - current.count };
}
