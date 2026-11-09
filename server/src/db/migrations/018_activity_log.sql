-- Who did what, and when: one line per action, written as it happens
-- (features/activity/log.js). Each line says which class and students it
-- concerns, so every role sees exactly its part (features/activity).
-- Private chats are never logged.

CREATE TABLE activity_log (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  -- Kept as they were, so the line still reads well if the account goes.
  actor_name      TEXT NOT NULL,
  actor_role      TEXT NOT NULL,
  -- attendance, grades, homework, announcement, people, academics, finance,
  -- transport, material
  kind            TEXT NOT NULL,
  -- e.g. "attendance.taken", "homework.graded"
  action          TEXT NOT NULL,
  -- "Ahmed Kareem took attendance for 5th A, period 2 (Mathematics): 2 absent"
  summary         TEXT NOT NULL,
  class_id        TEXT REFERENCES classes(id) ON DELETE SET NULL,
  -- The students it is about (their parents see it too).
  student_ids     TEXT[] NOT NULL DEFAULT '{}',
  -- Where tapping the line leads in the app.
  route           TEXT
);
CREATE INDEX activity_log_school ON activity_log (institution_id, at DESC);
CREATE INDEX activity_log_class ON activity_log (class_id, at DESC);
CREATE INDEX activity_log_students ON activity_log USING GIN (student_ids);
