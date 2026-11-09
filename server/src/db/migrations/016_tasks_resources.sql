-- Personal tasks and reminders, and study material teachers share.

-- Each person's own to-dos. The app makes the ID (so a new task shows at
-- once), so it is unique per person, not across the platform.
CREATE TABLE tasks (
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id           TEXT NOT NULL,
  title        TEXT NOT NULL,
  note         TEXT,
  due_at       TIMESTAMPTZ NOT NULL,
  priority     TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  repeat       TEXT NOT NULL DEFAULT 'none' CHECK (repeat IN ('none', 'daily', 'weekly', 'monthly')),
  is_done      BOOLEAN NOT NULL DEFAULT false,
  is_reminder  BOOLEAN NOT NULL DEFAULT false,
  route        TEXT,
  PRIMARY KEY (user_id, id)
);

-- A file or a link a teacher (or the office) shares with a class.
CREATE TABLE resources (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  class_id        TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id      TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('pdf', 'slides', 'video', 'link')),
  file_id         TEXT REFERENCES files(id) ON DELETE CASCADE,
  url             TEXT,
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((file_id IS NULL) <> (url IS NULL))
);
CREATE INDEX resources_class ON resources (class_id, created_at DESC);
