-- Reminders already sent, so a job that runs again (a restart, a retry, two
-- workers) never tells anyone twice. Old rows are cleaned up nightly.
CREATE TABLE sent_reminders (
  key      TEXT PRIMARY KEY,   -- e.g. "exam-today:<examId>"
  sent_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
