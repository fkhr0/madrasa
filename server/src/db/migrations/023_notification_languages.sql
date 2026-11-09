-- Notifications in both languages, shown in the language the app is set to
-- now (one person may use Arabic on the phone and English on a computer).
-- title/body stay the English text; older rows keep what they had.
ALTER TABLE notifications ADD COLUMN title_ar TEXT;
ALTER TABLE notifications ADD COLUMN body_ar TEXT;

-- Each phone's app language, so its pushes arrive in that language.
ALTER TABLE push_subscriptions ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
ALTER TABLE device_tokens ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'
  CHECK (language IN ('ar', 'en'));
