-- Lookups that run on most screens, so they don't read whole tables as the
-- school grows.
-- A teacher's subjects and classes (timetable, attendance, homework, chats).
CREATE INDEX IF NOT EXISTS class_subjects_teacher ON class_subjects (teacher_id);
-- A class's students (attendance sheets, notifications to a class).
CREATE INDEX IF NOT EXISTS users_class ON users (institution_id, class_name);
-- A child's parents (every notification about a student).
CREATE INDEX IF NOT EXISTS parent_children_child ON parent_children (child_id);
-- The class a teacher is head teacher of.
CREATE INDEX IF NOT EXISTS classes_homeroom_teacher ON classes (homeroom_teacher_id);
-- "What did this person do" in Activity.
CREATE INDEX IF NOT EXISTS activity_log_actor ON activity_log (actor_id, at DESC);
-- Money taken on a day (the office's day and summaries).
CREATE INDEX IF NOT EXISTS payments_school_day ON payments (institution_id, paid_at);
