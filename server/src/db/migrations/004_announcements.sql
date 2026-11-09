-- Announcements: the school's notice board.
-- Administrators write to anyone; teachers write to the classes they teach.

CREATE TABLE announcements (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  -- school = everyone, class = one class (students, their parents, its
  -- teachers), parents = all parents, teachers = all teachers.
  audience        TEXT NOT NULL
                  CHECK (audience IN ('school', 'class', 'parents', 'teachers')),
  -- Deleting a class deletes its announcements too.
  class_id        TEXT REFERENCES classes(id) ON DELETE CASCADE,
  author_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
  -- Shown as the sender, e.g. "Exams Office" or the teacher's name.
  author_name     TEXT NOT NULL,
  -- A future time schedules it: nobody sees it before then.
  published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_pinned       BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((audience = 'class') = (class_id IS NOT NULL))
);
CREATE INDEX announcements_institution ON announcements (institution_id, published_at DESC);
