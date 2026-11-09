// SQL for subjects and classes. Always limited to one institution.
const database = require("../../db/database");
const { query, queryOne } = database;

// ---------- Subjects ----------

function listSubjects(institutionId) {
  return query(
    `SELECT s.id, s.name, s.icon, s.color,
            (SELECT COUNT(*)::int FROM class_subjects cs WHERE cs.subject_id = s.id)
              AS "classCount"
     FROM subjects s WHERE s.institution_id = $1 ORDER BY s.name`,
    [institutionId],
  );
}

function insertSubject(institutionId, { name, icon, color }) {
  return queryOne(
    `INSERT INTO subjects (institution_id, name, icon, color)
     VALUES ($1, $2, $3, $4) RETURNING id, name, icon, color`,
    [institutionId, name, icon, color],
  );
}

function updateSubject(institutionId, id, { name, icon, color }) {
  return queryOne(
    `UPDATE subjects SET name = $3, icon = $4, color = $5
     WHERE institution_id = $1 AND id = $2
     RETURNING id, name, icon, color`,
    [institutionId, id, name, icon, color],
  );
}

async function deleteSubject(institutionId, id) {
  const rows = await query(
    "DELETE FROM subjects WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, id],
  );
  return rows.length > 0;
}

// ---------- Classes ----------

/** Classes with their head teacher, student count and subjects. */
async function listClasses(institutionId, classId = null) {
  const classes = await query(
    `SELECT c.id, c.name, c.homeroom_teacher_id AS "homeroomTeacherId",
            t.name AS "homeroomTeacherName",
            (SELECT COUNT(*)::int FROM users s
             WHERE s.institution_id = c.institution_id AND s.role = 'student'
               AND s.class_name = c.name) AS "studentCount"
     FROM classes c
     LEFT JOIN users t ON t.id = c.homeroom_teacher_id
     WHERE c.institution_id = $1 AND ($2::text IS NULL OR c.id = $2)
     ORDER BY c.name`,
    [institutionId, classId],
  );
  if (classes.length === 0) return classes;

  const subjects = await query(
    `SELECT cs.class_id, cs.subject_id AS "subjectId", s.name AS "subjectName",
            cs.teacher_id AS "teacherId", t.name AS "teacherName"
     FROM class_subjects cs
     JOIN subjects s ON s.id = cs.subject_id
     LEFT JOIN users t ON t.id = cs.teacher_id
     WHERE cs.class_id = ANY($1)
     ORDER BY s.name`,
    [classes.map((c) => c.id)],
  );

  return classes.map((c) => ({
    ...c,
    subjects: subjects
      .filter((s) => s.class_id === c.id)
      .map(({ class_id: _, ...s }) => s),
  }));
}

async function findClass(institutionId, classId) {
  return (await listClasses(institutionId, classId))[0] ?? null;
}

async function insertClass(tx, institutionId, { name, homeroomTeacherId, subjectIds }) {
  const row = await tx.queryOne(
    `INSERT INTO classes (institution_id, name, homeroom_teacher_id)
     VALUES ($1, $2, $3) RETURNING id`,
    [institutionId, name, homeroomTeacherId ?? null],
  );
  for (const subjectId of subjectIds) {
    await tx.query(
      "INSERT INTO class_subjects (class_id, subject_id) VALUES ($1, $2)",
      [row.id, subjectId],
    );
  }
  return row.id;
}

/** Renames the class (and moves its students to the new name). */
async function updateClass(tx, institutionId, old, { name, homeroomTeacherId }) {
  await tx.query(
    `UPDATE classes SET name = $3, homeroom_teacher_id = $4
     WHERE institution_id = $1 AND id = $2`,
    [institutionId, old.id, name, homeroomTeacherId ?? null],
  );
  if (name !== old.name) {
    await tx.query(
      `UPDATE users SET class_name = $3
       WHERE institution_id = $1 AND role = 'student' AND class_name = $2`,
      [institutionId, old.name, name],
    );
  }
}

async function deleteClass(institutionId, classId) {
  const rows = await query(
    "DELETE FROM classes WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, classId],
  );
  return rows.length > 0;
}

/** Adds the subject to the class, or changes its teacher (null = none). */
function setClassSubject(classId, subjectId, teacherId) {
  return query(
    `INSERT INTO class_subjects (class_id, subject_id, teacher_id)
     VALUES ($1, $2, $3)
     ON CONFLICT (class_id, subject_id) DO UPDATE SET teacher_id = $3`,
    [classId, subjectId, teacherId ?? null],
  );
}

async function removeClassSubject(classId, subjectId) {
  const rows = await query(
    `DELETE FROM class_subjects WHERE class_id = $1 AND subject_id = $2
     RETURNING class_id`,
    [classId, subjectId],
  );
  return rows.length > 0;
}

// ---------- Checks ----------

/** True when every ID is a teacher of the institution (nulls are skipped). */
async function areTeachers(institutionId, ids) {
  const wanted = [...new Set(ids.filter(Boolean))];
  if (wanted.length === 0) return true;
  const row = await queryOne(
    `SELECT COUNT(*)::int AS n FROM users
     WHERE institution_id = $1 AND role = 'teacher' AND id = ANY($2)`,
    [institutionId, wanted],
  );
  return row.n === wanted.length;
}

async function areSubjects(institutionId, ids) {
  const wanted = [...new Set(ids)];
  if (wanted.length === 0) return true;
  const row = await queryOne(
    `SELECT COUNT(*)::int AS n FROM subjects
     WHERE institution_id = $1 AND id = ANY($2)`,
    [institutionId, wanted],
  );
  return row.n === wanted.length;
}

module.exports = {
  listSubjects,
  insertSubject,
  updateSubject,
  deleteSubject,
  listClasses,
  findClass,
  insertClass,
  updateClass,
  deleteClass,
  setClassSubject,
  removeClassSubject,
  areTeachers,
  areSubjects,
};
