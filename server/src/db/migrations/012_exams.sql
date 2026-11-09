-- Exams and their results. One exam is for one class and one subject; its
-- published scores are the student's grades.

CREATE TABLE exams (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id    TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  class_id          TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id        TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  -- Iraqi exam kinds: quiz (يومي), monthly (شهري), mid-year (نصف السنة), final (نهائي).
  type              TEXT NOT NULL CHECK (type IN ('quiz', 'monthly', 'midYear', 'final')),
  title             TEXT NOT NULL,
  date              DATE NOT NULL,
  start_time        TIME NOT NULL DEFAULT '08:00',
  duration_minutes  INTEGER NOT NULL DEFAULT 45 CHECK (duration_minutes BETWEEN 5 AND 300),
  room              TEXT NOT NULL DEFAULT '',
  topics            TEXT[] NOT NULL DEFAULT '{}',
  max_score         NUMERIC(6, 2) NOT NULL DEFAULT 100 CHECK (max_score > 0),
  -- Students see scores only once the teacher publishes them.
  published_at      TIMESTAMPTZ,
  created_by        TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX exams_class ON exams (class_id, date);

-- No row (or a null score) = no mark, e.g. the student was absent.
CREATE TABLE exam_scores (
  exam_id     TEXT NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  student_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score       NUMERIC(6, 2) NOT NULL CHECK (score >= 0),
  PRIMARY KEY (exam_id, student_id)
);
