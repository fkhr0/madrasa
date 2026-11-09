-- School buses: lines, their stops, who rides them, and today's trips.

-- The school's rules for when a trip may start.
CREATE TABLE transport_settings (
  institution_id       TEXT PRIMARY KEY REFERENCES institutions(id) ON DELETE CASCADE,
  opens_before_minutes INTEGER NOT NULL DEFAULT 45,
  closes_after_minutes INTEGER NOT NULL DEFAULT 60,
  -- Drivers may start any trip at any time (for trying the app out).
  test_mode            BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE bus_routes (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id    TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  bus_number        TEXT NOT NULL,
  plate_number      TEXT NOT NULL DEFAULT '',
  -- A driver drives one bus.
  driver_id         TEXT UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  supervisor_name   TEXT NOT NULL DEFAULT '',
  supervisor_phone  TEXT NOT NULL DEFAULT '',
  capacity          INTEGER NOT NULL CHECK (capacity > 0),
  -- When the bus reaches / leaves the school; the school itself is the
  -- institution's location, so moving the school moves every line.
  school_morning_minute   INTEGER NOT NULL DEFAULT 465,
  school_afternoon_minute INTEGER NOT NULL DEFAULT 800,
  UNIQUE (institution_id, name)
);

-- Pick-up stops in morning order (the school is added after the last one).
CREATE TABLE bus_stops (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  position          INTEGER NOT NULL,
  name              TEXT NOT NULL,
  landmark          TEXT NOT NULL DEFAULT '',
  latitude          DOUBLE PRECISION NOT NULL,
  longitude         DOUBLE PRECISION NOT NULL,
  -- Minutes after midnight (07:22 = 442).
  morning_minute    INTEGER NOT NULL,
  afternoon_minute  INTEGER NOT NULL
);
CREATE INDEX bus_stops_route ON bus_stops (route_id, position);

-- A student rides one bus, from one stop.
CREATE TABLE route_students (
  student_id        TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  -- Deleting a stop takes its students off the line.
  stop_id           TEXT NOT NULL REFERENCES bus_stops(id) ON DELETE CASCADE,
  -- The parent said the child won't ride on this day.
  not_riding_on     DATE
);

-- One row per trip driven. The driver's phone moves it on.
CREATE TABLE bus_trips (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  route_id          TEXT NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  direction         TEXT NOT NULL CHECK (direction IN ('toSchool', 'toHome')),
  trip_date         DATE NOT NULL,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ,
  early_reason      TEXT,
  -- Stop IDs in driving order, fixed when the trip starts.
  stop_ids          TEXT[] NOT NULL,
  -- When each stop was reached (null until then), same order.
  reached_at        TIMESTAMPTZ[] NOT NULL,
  -- -1 while driving to the first stop.
  reached_index     INTEGER NOT NULL DEFAULT 0,
  -- Null while the bus stands at stop_ids[reached_index].
  left_stop_at      TIMESTAMPTZ,
  delay_minutes     INTEGER NOT NULL DEFAULT 0,
  delay_reason      TEXT,
  -- The last GPS point from the driver's phone.
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  position_at       TIMESTAMPTZ,
  boarded_ids       TEXT[] NOT NULL DEFAULT '{}',
  absent_ids        TEXT[] NOT NULL DEFAULT '{}',
  UNIQUE (route_id, trip_date, direction)
);
