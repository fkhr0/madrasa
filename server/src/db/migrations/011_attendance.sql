-- Attendance, taken by the teacher of each lesson: one mark per student per
-- period of a day. A student's day (present, late, absent) is worked out
-- from these marks; the office can excuse a whole day.

CREATE TABLE attendance_marks (
  student_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date          DATE NOT NULL,
  period        INTEGER NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('present', 'late', 'absent')),
  class_id      TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  -- Kept as it was that day, so history survives timetable changes.
  subject_name  TEXT NOT NULL,
  marked_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  marked_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, date, period)
);
CREATE INDEX attendance_marks_lesson ON attendance_marks (class_id, date, period);

-- A day the office excused (medical note, family event…).
CREATE TABLE attendance_excuses (
  student_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  note        TEXT NOT NULL DEFAULT '',
  created_by  TEXT REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (student_id, date)
);
