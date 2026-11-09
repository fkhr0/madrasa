-- Each person's language (the app sends it), so notifications reach them in
-- Arabic or English; and activity lines kept in both, for every reader.
ALTER TABLE users ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
ALTER TABLE activity_log ADD COLUMN summary_ar TEXT;
