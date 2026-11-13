// Brings the database up to date: runs every file in migrations/ that hasn't
// run yet, in name order (001_, 002_, ...).
const fs = require("fs");
const path = require("path");
const { db, query } = require("./database");

const DIR = path.join(__dirname, "migrations");

async function migrate() {
  await db().exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name        TEXT PRIMARY KEY,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  const done = new Set(
    (await query("SELECT name FROM schema_migrations")).map((r) => r.name),
  );
  const files = fs
    .readdirSync(DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  const applied = [];
  for (const file of files) {
    if (done.has(file)) continue;

    const sql = fs.readFileSync(path.join(DIR, file), "utf8");
    // One transaction per file: a failing migration leaves nothing half-done.
    // (file names come from our own folder, so they are safe to inline)
    try {
      await db().exec(`
        BEGIN;
        ${sql}
        INSERT INTO schema_migrations (name) VALUES ('${file}');
        COMMIT;
      `);
    } catch (err) {
      await db().exec("ROLLBACK");
      throw new Error(`Migration ${file} failed: ${err.message}`);
    }
    applied.push(file);
  }

  return applied;
}

module.exports = { migrate };
