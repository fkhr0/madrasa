// Web Push: notifications on the phone even when the app is closed.
const fs = require("fs");
const path = require("path");
const webPush = require("web-push");
const config = require("../../config");
const { query } = require("../../db/database");
const { chunks } = require("../../common/chunks");

/** Pushes sent at the same time. */
const SEND_AT_ONCE = 50;

const KEYS_FILE =
  process.env.PUSH_KEYS_FILE ||
  path.join(path.dirname(path.resolve(config.localDataDir)), "push-keys.json");

let keys = null;

/** The server's key pair, made the first time it is needed. */
function pushKeys() {
  if (keys) return keys;
  if (process.env.VAPID_PUBLIC_KEY && process.env.VAPID_PRIVATE_KEY) {
    keys = { publicKey: process.env.VAPID_PUBLIC_KEY, privateKey: process.env.VAPID_PRIVATE_KEY };
  } else if (fs.existsSync(KEYS_FILE)) {
    keys = JSON.parse(fs.readFileSync(KEYS_FILE, "utf8"));
  } else {
    keys = webPush.generateVAPIDKeys();
    fs.mkdirSync(path.dirname(KEYS_FILE), { recursive: true });
    fs.writeFileSync(KEYS_FILE, JSON.stringify(keys));
  }
  // Push services ask for a contact for the sender.
  webPush.setVapidDetails("mailto:admin@school.local", keys.publicKey, keys.privateKey);
  return keys;
}

function saveSubscription(userId, { endpoint, keys: k, language = "ar" }) {
  return query(
    `INSERT INTO push_subscriptions (endpoint, user_id, p256dh, auth, language)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (endpoint) DO UPDATE SET user_id = $2, p256dh = $3, auth = $4, language = $5`,
    [endpoint, userId, k.p256dh, k.auth, language],
  );
}

function removeSubscription(userId, endpoint) {
  return query("DELETE FROM push_subscriptions WHERE endpoint = $1 AND user_id = $2", [
    endpoint,
    userId,
  ]);
}

/**
 * Sends to every phone of [userIds] that turned notifications on.
 * Phones that turned them off (410 / 404) are forgotten.
 */
async function sendPush(userIds, { texts, route }) {
  const subscriptions = await query(
    "SELECT endpoint, p256dh, auth, language FROM push_subscriptions WHERE user_id = ANY($1)",
    [userIds],
  );
  if (subscriptions.length === 0) return;
  pushKeys();

  // Each phone in its app's language.
  const payloads = {
    en: JSON.stringify({ ...texts.en, route }),
    ar: JSON.stringify({ ...texts.ar, route }),
  };
  // 50 at a time: a message to the whole school doesn't open thousands of
  // connections at once.
  for (const part of chunks(subscriptions, SEND_AT_ONCE)) {
    await Promise.all(part.map((s) => sendOne(s, payloads[s.language] ?? payloads.ar)));
  }
}

async function sendOne(s, payload) {
  try {
    await webPush.sendNotification(
      { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
      payload,
      { TTL: 60 * 60 },
    );
  } catch (e) {
    // The phone turned notifications off or the app was removed.
    if (e.statusCode === 404 || e.statusCode === 410) {
      await query("DELETE FROM push_subscriptions WHERE endpoint = $1", [s.endpoint]);
    }
  }
}

module.exports = { pushKeys, saveSubscription, removeSubscription, sendPush };
