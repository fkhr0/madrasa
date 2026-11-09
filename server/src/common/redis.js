// One shared Redis connection (rate limits, caches, live updates between
// servers). Only used when REDIS_URL is set; BullMQ keeps its own.
const config = require("../config");

let shared = null;
/** Extra connections (subscribers), closed with the shared one. */
const others = [];

/** The shared connection (made the first time it is needed). */
function client() {
  if (!config.redisUrl) throw new Error("REDIS_URL is not set");
  if (!shared) {
    const IORedis = require("ioredis");
    shared = new IORedis(config.redisUrl, { maxRetriesPerRequest: 3 });
    shared.on("error", (e) => console.warn(`Redis: ${e.message}`));
  }
  return shared;
}

/** A new connection (subscribers can't share one). */
function newConnection() {
  const IORedis = require("ioredis");
  const connection = new IORedis(config.redisUrl, { maxRetriesPerRequest: 3 });
  connection.on("error", (e) => console.warn(`Redis: ${e.message}`));
  others.push(connection);
  return connection;
}

async function closeRedis() {
  await shared?.quit().catch(() => {});
  shared = null;
  for (const connection of others.splice(0)) await connection.quit().catch(() => {});
}

module.exports = { client, newConnection, closeRedis };
