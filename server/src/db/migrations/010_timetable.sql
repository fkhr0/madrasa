CREATE TABLE periods (
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  number          INTEGER NOT NULL CHECK (number BETWEEN 1 AND 12),
  start_time      TIME NOT NULL,
  end_time        TIME NOT NULL,
  PRIMARY KEY (institution_id, number),
  CHECK (end_time > start_time)
);

CREATE TABLE timetable_slots (
  class_id    TEXT NOT NULL,
  weekday     INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  period      INTEGER NOT NULL,
  subject_id  TEXT NOT NULL,
  room        TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (class_id, weekday, period),
  FOREIGN KEY (class_id, subject_id)
    REFERENCES class_subjects (class_id, subject_id) ON DELETE CASCADE
);
CREATE INDEX timetable_slots_subject ON timetable_slots (subject_id);

