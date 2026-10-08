// Fixed-window rate limit stored in D1, keyed by a salted IP hash.

export const RATE_WINDOW_MS = 10 * 60 * 1000;
export const RATE_LIMIT = 5;
const RETENTION_MS = 24 * 60 * 60 * 1000;

const HIT_SQL = `INSERT INTO rate_limits (ip_hash, window_start, count) VALUES (?, ?, 1)
  ON CONFLICT (ip_hash, window_start) DO UPDATE SET count = count + 1
  RETURNING count`;
const PRUNE_SQL = "DELETE FROM rate_limits WHERE window_start < ?";

/** Count one submission for this IP hash; returns whether it is within the limit. */
export async function hitRateLimit(db, ipHash, nowMs) {
  const windowStart = Math.floor(nowMs / RATE_WINDOW_MS) * RATE_WINDOW_MS;
  const row = await db.prepare(HIT_SQL).bind(ipHash, windowStart).first();
  await db.prepare(PRUNE_SQL).bind(nowMs - RETENTION_MS).run();
  const count = Number(row?.count ?? 1);
  const retryAfterSeconds = Math.max(1, Math.ceil((windowStart + RATE_WINDOW_MS - nowMs) / 1000));
  return { allowed: count <= RATE_LIMIT, count, retryAfterSeconds };
}
