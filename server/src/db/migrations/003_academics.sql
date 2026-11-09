-- Subjects and classes, managed by the administrator.

CREATE TABLE subjects (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  -- How the app draws it: an icon name and a colour name it knows.
  icon            TEXT NOT NULL DEFAULT 'book',
  color           TEXT NOT NULL DEFAULT 'blue',
  UNIQUE (institution_id, name)
);

CREATE TABLE classes (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id       TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name                 TEXT NOT NULL,          -- "5th Scientific – A"
  -- The head of the class (homeroom teacher).
  homeroom_teacher_id  TEXT REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (institution_id, name)
);

-- Which subjects a class studies, and who teaches each one there.
CREATE TABLE class_subjects (
  class_id    TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id  TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id  TEXT REFERENCES users(id) ON DELETE SET NULL,  -- null = not assigned yet
  PRIMARY KEY (class_id, subject_id)
);
