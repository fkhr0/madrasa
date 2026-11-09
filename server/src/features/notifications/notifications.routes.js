// The signed-in person's notifications (the bell).
const express = require("express");
const { query } = require("../../db/database");
const { requireAuth } = require("../../common/auth-middleware");
const { validate, z } = require("../../common/http");
const push = require("./push");
const fcm = require("./fcm");

const router = express.Router();
router.use(requireAuth);

// GET /notifications -> [notification], newest first (the last 100), in the
// language the app asks for (X-Language).
router.get("/", async (req, res) => {
  const arabic = req.language === "ar";
  res.json(
    await query(
      `SELECT id, type,
              CASE WHEN $2 THEN COALESCE(title_ar, title) ELSE title END AS title,
              CASE WHEN $2 THEN COALESCE(body_ar, body) ELSE body END AS body,
              route, created_at AS "createdAt", read_at IS NOT NULL AS "isRead"
       FROM notifications WHERE user_id = $1
       ORDER BY created_at DESC LIMIT 100`,
      [req.user.id, arabic],
    ),
  );
});

// POST /notifications/:id/read -> 204
router.post("/:id/read", async (req, res) => {
  await query(
    "UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 AND read_at IS NULL",
    [req.params.id, req.user.id],
  );
  res.status(204).end();
});

// POST /notifications/read-all -> 204
router.post("/read-all", async (req, res) => {
  await query(
    "UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL",
    [req.user.id],
  );
  res.status(204).end();
});

// ---------- Web Push (notifications while the app is closed) ----------

// GET /notifications/push-key -> { publicKey }  (for the browser to subscribe)
router.get("/push-key", (_req, res) => {
  res.json({ publicKey: push.pushKeys().publicKey });
});

const subscription = z.object({
  endpoint: z.string().url(),
  keys: z.object({ p256dh: z.string().min(10), auth: z.string().min(5) }),
});
const language = z.enum(["ar", "en"]).default("ar");

// POST /notifications/push { endpoint, keys } -> 204  (this phone wants them)
router.post("/push", async (req, res) => {
  await push.saveSubscription(req.user.id, {
    ...validate(subscription, req.body),
    // The phone's app language (its pushes come in it).
    language: validate(language, req.body.language ?? req.language),
  });
  res.status(204).end();
});

// DELETE /notifications/push { endpoint } -> 204  (this phone stops them)
router.delete("/push", async (req, res) => {
  const { endpoint } = validate(z.object({ endpoint: z.string() }), req.body);
  await push.removeSubscription(req.user.id, endpoint);
  res.status(204).end();
});

// POST /notifications/devices { token, platform } -> 204
// An Android phone's Firebase token (notifications when the app is closed).
router.post("/devices", async (req, res) => {
  const device = validate(
    z.object({
      token: z.string().min(20).max(4096),
      platform: z.enum(["android", "ios"]),
      language: z.enum(["ar", "en"]).default(req.language === "en" ? "en" : "ar"),
    }),
    req.body,
  );
  await fcm.saveDevice(req.user.id, device);
  res.status(204).end();
});

// DELETE /notifications/devices { token } -> 204  (signed out on this phone)
router.delete("/devices", async (req, res) => {
  const { token } = validate(z.object({ token: z.string() }), req.body);
  await fcm.removeDevice(req.user.id, token);
  res.status(204).end();
});

module.exports = router;
