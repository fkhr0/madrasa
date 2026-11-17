const { query } = require("../../db/database");

const known = new Map();

function rememberLanguage(userId, language) {
  if (!language || known.get(userId) === language) return;
  known.set(userId, language);
  query("UPDATE users SET language = $2 WHERE id = $1 AND language <> $2", [userId, language])
    .catch(() => known.delete(userId));
}

async function languagesOf(userIds) {
  if (userIds.length === 0) return new Map();
  const rows = await query("SELECT id, language FROM users WHERE id = ANY($1)", [userIds]);
  return new Map(rows.map((r) => [r.id, r.language]));
}

module.exports = { rememberLanguage, languagesOf };
