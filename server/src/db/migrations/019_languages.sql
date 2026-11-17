ALTER TABLE users ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
ALTER TABLE activity_log ADD COLUMN summary_ar TEXT;
