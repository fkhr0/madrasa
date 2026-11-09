-- Android phones that get notifications through Firebase (FCM), one row per
-- phone; token = the phone's Firebase Installation ID (FID).
-- The browser app's Web Push subscriptions stay in push_subscriptions.
CREATE TABLE device_tokens (
  token       TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  created_at  TIMESTAMPTZ(3) NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ(3) NOT NULL DEFAULT now()
);
CREATE INDEX device_tokens_user ON device_tokens (user_id);
