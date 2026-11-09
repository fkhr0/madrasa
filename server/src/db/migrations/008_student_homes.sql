-- Where each student lives, for door-to-door bus pick-up.
-- The family shares it from the app, or the administrator sets it (e.g. from
-- a location the family sent on WhatsApp). The bus stop is made from it.
CREATE TABLE student_homes (
  student_id  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  -- A few words to find the door, e.g. "green gate next to the bakery".
  note        TEXT NOT NULL DEFAULT '',
  -- "family" or "school": who set it.
  set_by      TEXT NOT NULL CHECK (set_by IN ('family', 'school')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
