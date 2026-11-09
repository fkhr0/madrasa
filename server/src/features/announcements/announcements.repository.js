// SQL for announcements. Always limited to one institution.
const { query, queryOne } = require("../../db/database");

const COLUMNS = `a.id, a.title, a.body, a.audience, c.name AS "className",
  a.author_id AS "authorId", a.author_name AS "authorName",
  a.published_at AS "publishedAt", a.is_pinned AS "isPinned"`;

const FROM = "FROM announcements a LEFT JOIN classes c ON c.id = a.class_id";

/** Classes a teacher teaches a subject in, or is the head teacher of. */
const TEACHER_CLASSES = `
  SELECT id FROM classes WHERE homeroom_teacher_id = $2
  UNION SELECT class_id FROM class_subjects WHERE teacher_id = $2`;

/** What each role may read. */
function listFor(user) {
  const visible = {
    admin: "true",
    student: `a.audience = 'school' OR (a.audience = 'class' AND c.name =
      (SELECT class_name FROM users WHERE id = $2))`,
    parent: `a.audience IN ('school', 'parents') OR (a.audience = 'class' AND c.name IN
      (SELECT u.class_name FROM parent_children pc JOIN users u ON u.id = pc.child_id
       WHERE pc.parent_id = $2))`,
    teacher: `a.audience IN ('school', 'teachers') OR (a.audience = 'class' AND
      a.class_id IN (${TEACHER_CLASSES}))`,
    driver: "a.audience = 'school'",
  }[user.role] ?? "false";

  return query(
    `SELECT ${COLUMNS} ${FROM}
     WHERE a.institution_id = $1 AND a.published_at <= now()
       -- Mentions $2 so its type is known even when a rule doesn't use it.
       AND $2::text IS NOT NULL AND (${visible})
     ORDER BY a.is_pinned DESC, a.published_at DESC`,
    [user.institutionId, user.id],
  );
}

function find(institutionId, id) {
  return queryOne(
    `SELECT ${COLUMNS}, a.class_id AS "classId" ${FROM}
     WHERE a.institution_id = $1 AND a.id = $2`,
    [institutionId, id],
  );
}

/** The class with this name in the school, or null. */
function findClassByName(institutionId, name) {
  return queryOne(
    "SELECT id FROM classes WHERE institution_id = $1 AND name = $2",
    [institutionId, name],
  );
}

async function teachesClass(teacherId, classId) {
  const rows = await query(
    `SELECT 1 FROM (${TEACHER_CLASSES.replaceAll("$2", "$1")}) t WHERE t.id = $2`,
    [teacherId, classId],
  );
  return rows.length > 0;
}

async function insert(institutionId, author, a) {
  const row = await queryOne(
    `INSERT INTO announcements (institution_id, title, body, audience, class_id,
                                author_id, author_name, published_at, is_pinned)
     VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8::timestamptz, now()), $9)
     RETURNING id`,
    [
      institutionId,
      a.title,
      a.body,
      a.audience,
      a.classId,
      author.id,
      author.name,
      a.publishedAt ?? null,
      a.isPinned,
    ],
  );
  return find(institutionId, row.id);
}

async function update(institutionId, id, a) {
  await query(
    `UPDATE announcements
     SET title = $3, body = $4, audience = $5, class_id = $6, is_pinned = $7
     WHERE institution_id = $1 AND id = $2`,
    [institutionId, id, a.title, a.body, a.audience, a.classId, a.isPinned],
  );
  return find(institutionId, id);
}

async function remove(institutionId, id) {
  const rows = await query(
    "DELETE FROM announcements WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, id],
  );
  return rows.length > 0;
}

module.exports = {
  listFor,
  find,
  findClassByName,
  teachesClass,
  insert,
  update,
  remove,
};
