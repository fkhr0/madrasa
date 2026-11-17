CREATE TABLE student_homes (
  student_id  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  note        TEXT NOT NULL DEFAULT '',
  set_by      TEXT NOT NULL CHECK (set_by IN ('family', 'school')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
