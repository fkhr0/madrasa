-- Uploaded files, and homework: a teacher sets work for a class, students
-- hand it in (with files), the teacher grades it with feedback.

-- The bytes are on disk (config.uploadsDir/<id>); this is what we know about them.
CREATE TABLE files (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  uploaded_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  name            TEXT NOT NULL,
  mime            TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes      INTEGER NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE assignments (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id    TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  class_id          TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id        TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  type              TEXT NOT NULL CHECK (type IN ('homework', 'assignment', 'project', 'quiz')),
  title             TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  due_at            TIMESTAMPTZ NOT NULL,
  allows_late       BOOLEAN NOT NULL DEFAULT false,
  accepts_files     BOOLEAN NOT NULL DEFAULT true,
  max_grade         NUMERIC(6, 2) NOT NULL DEFAULT 10 CHECK (max_grade > 0),
  created_by        TEXT REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX assignments_class ON assignments (class_id, due_at);

-- The teacher's files for the work (worksheet, template…).
CREATE TABLE assignment_attachments (
  assignment_id  TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  file_id        TEXT NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  PRIMARY KEY (assignment_id, file_id)
);

-- One per student who handed in, or who was graded (work on paper has no
-- submitted_at).
CREATE TABLE submissions (
  assignment_id  TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  submitted_at   TIMESTAMPTZ,
  grade          NUMERIC(6, 2) CHECK (grade >= 0),
  feedback       TEXT,
  graded_at      TIMESTAMPTZ,
  PRIMARY KEY (assignment_id, student_id)
);

CREATE TABLE submission_files (
  assignment_id  TEXT NOT NULL,
  student_id     TEXT NOT NULL,
  file_id        TEXT NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  PRIMARY KEY (assignment_id, student_id, file_id),
  FOREIGN KEY (assignment_id, student_id)
    REFERENCES submissions (assignment_id, student_id) ON DELETE CASCADE
);
