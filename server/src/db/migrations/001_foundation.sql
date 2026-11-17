CREATE TABLE institutions (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('school', 'university')),
  city        TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id                    TEXT PRIMARY KEY,
  institution_id        TEXT NOT NULL REFERENCES institutions(id),
  role                  TEXT NOT NULL
                        CHECK (role IN ('student', 'teacher', 'parent', 'admin', 'driver')),
  name                  TEXT NOT NULL,
  email                 TEXT NOT NULL DEFAULT '',
  phone                 TEXT NOT NULL DEFAULT '',
  password_hash         TEXT NOT NULL,
  class_name            TEXT,
  subject_name          TEXT,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  must_change_password  BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX users_institution_role ON users (institution_id, role);

CREATE TABLE parent_children (
  parent_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  child_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (parent_id, child_id)
);

CREATE TABLE sessions (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user ON sessions (user_id);

CREATE TABLE academic_years (
  id              TEXT PRIMARY KEY,
  institution_id  TEXT NOT NULL REFERENCES institutions(id),
  name            TEXT NOT NULL,
  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  working_days    INTEGER[] NOT NULL DEFAULT '{7,1,2,3,4}',
  is_current      BOOLEAN NOT NULL DEFAULT false,
  CHECK (end_date > start_date)
);
CREATE INDEX academic_years_institution ON academic_years (institution_id);

CREATE TABLE terms (
  id                SERIAL PRIMARY KEY,
  academic_year_id  TEXT NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  start_date        DATE NOT NULL,
  end_date          DATE NOT NULL
);

CREATE TABLE holidays (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  academic_year_id  TEXT NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  type              TEXT NOT NULL CHECK (type IN ('schoolBreak', 'national', 'religious')),
  start_date        DATE NOT NULL,
  end_date          DATE,
  CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE INDEX holidays_year ON holidays (academic_year_id);
