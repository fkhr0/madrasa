CREATE TABLE announcements (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  audience        TEXT NOT NULL
                  CHECK (audience IN ('school', 'class', 'parents', 'teachers')),
  class_id        TEXT REFERENCES classes(id) ON DELETE CASCADE,
  author_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
  author_name     TEXT NOT NULL,
  published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_pinned       BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((audience = 'class') = (class_id IS NOT NULL))
);
CREATE INDEX announcements_institution ON announcements (institution_id, published_at DESC);
