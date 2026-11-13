// SQL for the administrator's People directory.
const database = require("../../db/database");

const SELECT_USER = `
  SELECT u.id, u.institution_id, u.role, u.name, u.email, u.phone,
         u.class_name, u.subject_name, u.is_active, u.must_change_password,
         i.name AS school_name
  FROM users u
  JOIN institutions i ON i.id = u.institution_id`;

function listByRole(institutionId, role) {
  return database.query(
    `${SELECT_USER} WHERE u.institution_id = $1 AND u.role = $2 ORDER BY u.name`,
    [institutionId, role],
  );
}

function findInInstitution(institutionId, id, db = database) {
  return db.queryOne(
    `${SELECT_USER} WHERE u.institution_id = $1 AND u.id = $2`,
    [institutionId, id],
  );
}

/** The next free ID for a role this year, e.g. */
async function nextId(tx, prefix, year) {
  const start = `${prefix}-${year}-`;
  await tx.query("SELECT pg_advisory_xact_lock(hashtext($1))", [start]);

  // "STU-2026-0142" → part 3 → 142
  const row = await tx.queryOne(
    `SELECT COALESCE(MAX(CAST(split_part(id, '-', 3) AS INTEGER)), 0) AS last
     FROM users WHERE id LIKE $1`,
    [`${start}%`],
  );

  return `${start}${String(row.last + 1).padStart(4, "0")}`;
}

function insertUser(tx, user) {
  return tx.query(
    `INSERT INTO users (id, institution_id, role, name, email, phone, password_hash,
                        class_name, subject_name, must_change_password)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)`,
    [
      user.id,
      user.institutionId,
      user.role,
      user.name,
      user.email,
      user.phone,
      user.passwordHash,
      user.className ?? null,
      user.subjectName ?? null,
    ],
  );
}

function updateUser(tx, institutionId, id, fields) {
  return tx.query(
    `UPDATE users
     SET name = $3, email = $4, phone = $5, class_name = $6, subject_name = $7
     WHERE institution_id = $1 AND id = $2`,
    [
      institutionId,
      id,
      fields.name,
      fields.email,
      fields.phone,
      fields.className ?? null,
      fields.subjectName ?? null,
    ],
  );
}

function setActive(institutionId, id, isActive) {
  return database.query(
    "UPDATE users SET is_active = $3 WHERE institution_id = $1 AND id = $2",
    [institutionId, id, isActive],
  );
}

function setTemporaryPassword(institutionId, id, passwordHash) {
  return database.query(
    `UPDATE users SET password_hash = $3, must_change_password = true
     WHERE institution_id = $1 AND id = $2`,
    [institutionId, id, passwordHash],
  );
}

/** Replaces a parent's children. */
async function setChildren(tx, parentId, childIds) {
  await tx.query("DELETE FROM parent_children WHERE parent_id = $1", [
    parentId,
  ]);
  for (const childId of childIds) {
    await tx.query(
      "INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)",
      [parentId, childId],
    );
  }
}

/** How many of these IDs are students of the institution. */
async function countStudents(institutionId, ids) {
  if (ids.length === 0) return 0;
  const row = await database.queryOne(
    `SELECT COUNT(*)::int AS n FROM users
     WHERE institution_id = $1 AND role = 'student' AND id = ANY($2)`,
    [institutionId, ids],
  );
  return row.n;
}

async function deleteUser(institutionId, id) {
  const rows = await database.query(
    "DELETE FROM users WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, id],
  );
  return rows.length > 0;
}

/** Signs the person out on every device. */
const endSessions = (userId) =>
  database.query(
    `UPDATE sessions SET revoked_at = now()
     WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId],
  );

module.exports = {
  listByRole,
  findInInstitution,
  nextId,
  insertUser,
  updateUser,
  setActive,
  setTemporaryPassword,
  setChildren,
  countStudents,
  deleteUser,
  endSessions,
};
