CREATE TABLE subjects (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  icon            TEXT NOT NULL DEFAULT 'book',
  color           TEXT NOT NULL DEFAULT 'blue',
  UNIQUE (institution_id, name)
);

CREATE TABLE classes (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id       TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name                 TEXT NOT NULL,
  homeroom_teacher_id  TEXT REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (institution_id, name)
);

CREATE TABLE class_subjects (
  class_id    TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id  TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id  TEXT REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (class_id, subject_id)
);
