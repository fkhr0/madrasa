CREATE TABLE activity_log (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  actor_name      TEXT NOT NULL,
  actor_role      TEXT NOT NULL,
  kind            TEXT NOT NULL,
  action          TEXT NOT NULL,
  summary         TEXT NOT NULL,
  class_id        TEXT REFERENCES classes(id) ON DELETE SET NULL,
  student_ids     TEXT[] NOT NULL DEFAULT '{}',
  route           TEXT
);
CREATE INDEX activity_log_school ON activity_log (institution_id, at DESC);
CREATE INDEX activity_log_class ON activity_log (class_id, at DESC);
CREATE INDEX activity_log_students ON activity_log USING GIN (student_ids);
