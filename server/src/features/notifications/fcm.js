const fs = require("fs");
const config = require("../../config");
const { query } = require("../../db/database");
const { chunks } = require("../../common/chunks");

const PHONES_PER_REQUEST = 500;

const GONE = /not-registered|invalid-registration/;

let messaging;

function firebase() {
  if (messaging !== undefined) return messaging;
  if (!config.firebaseServiceAccountFile) return (messaging = null);
  const { initializeApp, cert } = require("firebase-admin/app");
  const { getMessaging } = require("firebase-admin/messaging");
  const account = JSON.parse(fs.readFileSync(config.firebaseServiceAccountFile, "utf8"));
  messaging = getMessaging(initializeApp({ credential: cert(account) }));
  return messaging;
}

function saveDevice(userId, { token, platform, language = "ar" }) {
  return query(
    `INSERT INTO device_tokens (token, user_id, platform, language) VALUES ($1, $2, $3, $4)
     ON CONFLICT (token) DO UPDATE
       SET user_id = $2, platform = $3, language = $4, updated_at = now()`,
    [token, userId, platform, language],
  );
}

function removeDevice(userId, token) {
  return query("DELETE FROM device_tokens WHERE token = $1 AND user_id = $2", [token, userId]);
}

async function sendToPhones(userIds, { texts, route }) {
  const fcm = firebase();
  if (!fcm) return;
  const rows = await query(
    "SELECT token, language FROM device_tokens WHERE user_id = ANY($1)",
    [userIds],
  );
  for (const language of ["ar", "en"]) {
    const tokens = rows.filter((r) => r.language === language).map((r) => r.token);
    await sendInLanguage(fcm, tokens, texts[language], route);
  }
}

async function sendInLanguage(fcm, tokens, { title, body }, route) {
  for (const part of chunks(tokens, PHONES_PER_REQUEST)) {
    const result = await fcm.sendEachForMulticast({
      fids: part,
      notification: { title, body: body || undefined },
      data: route ? { route } : {},
      android: {
        priority: "high",
        notification: { channelId: "school", icon: "ic_notification", color: "#4C5FD5" },
      },
    });
    const gone = part.filter((_, i) => GONE.test(result.responses[i].error?.code ?? ""));
    if (gone.length) await query("DELETE FROM device_tokens WHERE token = ANY($1)", [gone]);
  }
}

function useMessaging(fake) {
  messaging = fake;
}

module.exports = { saveDevice, removeDevice, sendToPhones, useMessaging };
