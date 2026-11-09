-- School events and meetings on the calendar, managed by the administrator.
-- (Holidays are in the study year; homework and exams come from their own tables.)

CREATE TABLE school_events (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('event', 'meeting')),
  -- Who sees it: everyone, families (parents + staff, e.g. parent–teacher
  -- meetings) or staff only (teachers + administrators).
  audience        TEXT NOT NULL DEFAULT 'everyone'
                  CHECK (audience IN ('everyone', 'families', 'staff')),
  event_date      DATE NOT NULL,
  -- "08:30"; null = all day. Kept as local school time, no time zones.
  start_time      TEXT CHECK (start_time ~ '^[0-2][0-9]:[0-5][0-9]$'),
  end_date        DATE,                   -- several days, e.g. a trip
  place           TEXT NOT NULL DEFAULT '',
  details         TEXT NOT NULL DEFAULT '',
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date IS NULL OR end_date >= event_date)
);
CREATE INDEX school_events_institution_date ON school_events (institution_id, event_date);
