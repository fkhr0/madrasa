CREATE INDEX IF NOT EXISTS class_subjects_teacher ON class_subjects (teacher_id);
CREATE INDEX IF NOT EXISTS users_class ON users (institution_id, class_name);
CREATE INDEX IF NOT EXISTS parent_children_child ON parent_children (child_id);
CREATE INDEX IF NOT EXISTS classes_homeroom_teacher ON classes (homeroom_teacher_id);
CREATE INDEX IF NOT EXISTS activity_log_actor ON activity_log (actor_id, at DESC);
CREATE INDEX IF NOT EXISTS payments_school_day ON payments (institution_id, paid_at);
