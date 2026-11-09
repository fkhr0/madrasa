-- The weekly timetable: the school's bell times, and which subject each class
-- has in each period of each study day. The teacher is not stored here: it is
-- whoever teaches that subject in that class (class_subjects.teacher_id).

-- Bell times, the same for every class of the school. Period 1, 2, 3…
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
  weekday     INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),  -- 1 = Monday … 7 = Sunday
  period      INTEGER NOT NULL,
  subject_id  TEXT NOT NULL,
  room        TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (class_id, weekday, period),
  -- Only subjects the class studies. Removing the subject from the class
  -- (or the class itself) removes its lessons too.
  FOREIGN KEY (class_id, subject_id)
    REFERENCES class_subjects (class_id, subject_id) ON DELETE CASCADE
);
CREATE INDEX timetable_slots_subject ON timetable_slots (subject_id);

-- Schools get default bell times at startup (timetable/default-periods.js).
