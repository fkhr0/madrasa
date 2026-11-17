CREATE TABLE transport_settings (
  institution_id       TEXT PRIMARY KEY REFERENCES institutions(id) ON DELETE CASCADE,
  opens_before_minutes INTEGER NOT NULL DEFAULT 45,
  closes_after_minutes INTEGER NOT NULL DEFAULT 60,
  test_mode            BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE bus_routes (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id    TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  bus_number        TEXT NOT NULL,
  plate_number      TEXT NOT NULL DEFAULT '',
  driver_id         TEXT UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  supervisor_name   TEXT NOT NULL DEFAULT '',
  supervisor_phone  TEXT NOT NULL DEFAULT '',
  capacity          INTEGER NOT NULL CHECK (capacity > 0),
  school_morning_minute   INTEGER NOT NULL DEFAULT 465,
  school_afternoon_minute INTEGER NOT NULL DEFAULT 800,
  UNIQUE (institution_id, name)
);

CREATE TABLE bus_stops (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  position          INTEGER NOT NULL,
  name              TEXT NOT NULL,
  landmark          TEXT NOT NULL DEFAULT '',
  latitude          DOUBLE PRECISION NOT NULL,
  longitude         DOUBLE PRECISION NOT NULL,
  morning_minute    INTEGER NOT NULL,
  afternoon_minute  INTEGER NOT NULL
);
CREATE INDEX bus_stops_route ON bus_stops (route_id, position);

CREATE TABLE route_students (
  student_id        TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  stop_id           TEXT NOT NULL REFERENCES bus_stops(id) ON DELETE CASCADE,
  not_riding_on     DATE
);

CREATE TABLE bus_trips (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  direction         TEXT NOT NULL CHECK (direction IN ('toSchool', 'toHome')),
  trip_date         DATE NOT NULL,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ,
  early_reason      TEXT,
  stop_ids          TEXT[] NOT NULL,
  reached_at        TIMESTAMPTZ[] NOT NULL,
  reached_index     INTEGER NOT NULL DEFAULT 0,
  left_stop_at      TIMESTAMPTZ,
  delay_minutes     INTEGER NOT NULL DEFAULT 0,
  delay_reason      TEXT,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  position_at       TIMESTAMPTZ,
  boarded_ids       TEXT[] NOT NULL DEFAULT '{}',
  absent_ids        TEXT[] NOT NULL DEFAULT '{}',
  UNIQUE (route_id, trip_date, direction)
);
