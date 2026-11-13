// Locks an ID after too many wrong passwords, whichever address they come from
// (guessing from many phones at once).
const config = require("../../config");

/** Wrong passwords allowed in the window before the ID is locked. */
const MAX_FAILURES = 5;
const WINDOW_SECONDS = 15 * 60;

const local = new Map(); // id -> { count, until }

const keyOf = (id) => `lock:${id}`;

/** Seconds until the ID can try again, or 0. */
async function lockedFor(id) {
  if (config.redisUrl) {
    const redis = require("../../common/redis").client();
    const [count, ttl] = await Promise.all([redis.get(keyOf(id)), redis.ttl(keyOf(id))]);
    return Number(count) >= MAX_FAILURES ? Math.max(ttl, 1) : 0;
  }
  const entry = local.get(id);
  if (!entry || entry.until < Date.now()) return 0;
  return entry.count >= MAX_FAILURES ? Math.ceil((entry.until - Date.now()) / 1000) : 0;
}

/** One more wrong password. Returns true when this one locked the ID. */
async function recordFailure(id) {
  if (config.redisUrl) {
    const redis = require("../../common/redis").client();
    const count = await redis.incr(keyOf(id));
    if (count === 1) await redis.expire(keyOf(id), WINDOW_SECONDS);
    return count === MAX_FAILURES;
  }
  const now = Date.now();
  const entry = local.get(id);
  const fresh = !entry || entry.until < now;
  const next = fresh
    ? { count: 1, until: now + WINDOW_SECONDS * 1000 }
    : { ...entry, count: entry.count + 1 };
  local.set(id, next);
  return next.count === MAX_FAILURES;
}

async function clearFailures(id) {
  if (config.redisUrl) {
    await require("../../common/redis").client().del(keyOf(id));
  } else {
    local.delete(id);
  }
}

module.exports = { lockedFor, recordFailure, clearFailures, MAX_FAILURES };
