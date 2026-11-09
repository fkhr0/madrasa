-- Notifications: one row per person told. The app shows them under the bell
-- and as a banner; Web Push brings them to the phone when the app is closed.
CREATE TABLE notifications (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- The app's NotificationType: transport, announcement, schedule…
  type            TEXT NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL DEFAULT '',
  -- Where tapping it leads in the app, e.g. "/bus".
  route           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at         TIMESTAMPTZ
);
CREATE INDEX notifications_user ON notifications (user_id, created_at DESC);

-- One-time bus alerts already sent on a trip (e.g. "near:s3"), so families
-- are told once, not on every GPS point.
ALTER TABLE bus_trips ADD COLUMN alerts_sent TEXT[] NOT NULL DEFAULT '{}';

-- Announcements are announced once: at once, or when a scheduled one is due.
ALTER TABLE announcements ADD COLUMN notified BOOLEAN NOT NULL DEFAULT false;
UPDATE announcements SET notified = true;

-- Phones that asked for notifications while the app is closed (Web Push).
-- One person can have several (phone, computer…).
CREATE TABLE push_subscriptions (
  endpoint    TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  p256dh      TEXT NOT NULL,
  auth        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX push_subscriptions_user ON push_subscriptions (user_id);
