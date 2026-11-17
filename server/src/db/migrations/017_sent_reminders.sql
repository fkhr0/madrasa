CREATE TABLE sent_reminders (
  key      TEXT PRIMARY KEY,
  sent_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
