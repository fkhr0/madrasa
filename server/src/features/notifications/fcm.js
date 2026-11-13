// Notifications on Android phones, even when the app is closed: Firebase Cloud
// Messaging (FCM, free).
const fs = require("fs");
const config = require("../../config");
const { query } = require("../../db/database");
const { chunks } = require("../../common/chunks");

/** FCM takes at most 500 phones per request. */
const PHONES_PER_REQUEST = 500;

/** Firebase's answer for a phone that no longer takes notifications. */
const GONE = /not-registered|invalid-registration/;

let messaging; // undefined: not tried yet; null: not set up

function firebase() {
  if (messaging !== undefined) return messaging;
  if (!config.firebaseServiceAccountFile) return (messaging = null);
  const { initializeApp, cert } = require("firebase-admin/app");
  const { getMessaging } = require("firebase-admin/messaging");
  const account = JSON.parse(fs.readFileSync(config.firebaseServiceAccountFile, "utf8"));
  messaging = getMessaging(initializeApp({ credential: cert(account) }));
  return messaging;
}

/** This phone (signed in as [userId]) wants notifications. */
function saveDevice(userId, { token, platform, language = "ar" }) {
  // A phone shared by a parent and a child: the token moves to whoever
  // signed in last.
  return query(
    `INSERT INTO device_tokens (token, user_id, platform, language) VALUES ($1, $2, $3, $4)
     ON CONFLICT (token) DO UPDATE
       SET user_id = $2, platform = $3, language = $4, updated_at = now()`,
    [token, userId, platform, language],
  );
}

/** Signed out on this phone: no more notifications for that person. */
function removeDevice(userId, token) {
  return query("DELETE FROM device_tokens WHERE token = $1 AND user_id = $2", [token, userId]);
}

/** Sends to every Android phone of [userIds], each in its app's language. */
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
      // Opened from the notification: the app goes to this page.
      data: route ? { route } : {},
      android: {
        priority: "high",
        notification: { channelId: "school", icon: "ic_notification", color: "#4C5FD5" },
      },
    });
    // The app was removed or notifications turned off: forget the token.
    const gone = part.filter((_, i) => GONE.test(result.responses[i].error?.code ?? ""));
    if (gone.length) await query("DELETE FROM device_tokens WHERE token = ANY($1)", [gone]);
  }
}

/** Tests: a stand-in for Firebase that records what would be sent. */
function useMessaging(fake) {
  messaging = fake;
}

module.exports = { saveDevice, removeDevice, sendToPhones, useMessaging };
