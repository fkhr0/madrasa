ALTER TABLE notifications ADD COLUMN title_ar TEXT;
ALTER TABLE notifications ADD COLUMN body_ar TEXT;

ALTER TABLE push_subscriptions ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
ALTER TABLE device_tokens ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
