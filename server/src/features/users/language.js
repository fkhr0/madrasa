// Each person's language, saved so that notifications sent to them later
// (alerts, reminders, summaries) are in the language their app shows.
const { query } = require("../../db/database");

/** User ID → the language last saved (to skip needless writes). */
const known = new Map();

function rememberLanguage(userId, language) {
  if (!language || known.get(userId) === language) return;
  known.set(userId, language);
  query("UPDATE users SET language = $2 WHERE id = $1 AND language <> $2", [userId, language])
    .catch(() => known.delete(userId));
}

/** User ID → "ar" | "en" for the given people. */
async function languagesOf(userIds) {
  if (userIds.length === 0) return new Map();
  const rows = await query("SELECT id, language FROM users WHERE id = ANY($1)", [userIds]);
  return new Map(rows.map((r) => [r.id, r.language]));
}

module.exports = { rememberLanguage, languagesOf };
