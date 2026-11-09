// SQL for homework, hand-ins and their files.
const { query, queryOne } = require("../../db/database");

const ASSIGNMENT = `
  SELECT a.id, a.class_id AS "classId", c.name AS "className",
         a.type, a.title, a.description,
         a.assigned_at AS "assignedAt", a.due_at AS "dueAt",
         a.allows_late AS "allowsLate", a.accepts_files AS "acceptsFiles",
         a.max_grade::float AS "maxGrade",
         s.id AS "subjectId", s.name AS "subjectName", s.icon, s.color,
         t.name AS "teacherName"
  FROM assignments a
  JOIN classes c ON c.id = a.class_id
  JOIN subjects s ON s.id = a.subject_id
  LEFT JOIN class_subjects cs ON cs.class_id = a.class_id AND cs.subject_id = a.subject_id
  LEFT JOIN users t ON t.id = cs.teacher_id`;

/** Adds attachments: [file] to each assignment. */
async function withAttachments(assignments) {
  if (assignments.length === 0) return assignments;
  const rows = await query(
    `SELECT aa.assignment_id, f.id, f.name, f.mime, f.size_bytes AS size
     FROM assignment_attachments aa JOIN files f ON f.id = aa.file_id
     WHERE aa.assignment_id = ANY($1) ORDER BY f.created_at`,
    [assignments.map((a) => a.id)],
  );
  return assignments.map((a) => ({
    ...a,
    attachments: rows
      .filter((r) => r.assignment_id === a.id)
      .map(({ assignment_id: _, ...file }) => file),
  }));
}

async function findAssignment(institutionId, id) {
  const [a] = await withAttachments(
    await query(`${ASSIGNMENT} WHERE a.institution_id = $1 AND a.id = $2`, [institutionId, id]),
  );
  return a ?? null;
}

/** A class's homework with how many handed in and how many are graded. */
async function classAssignments(classId) {
  return withAttachments(
    await query(
      `SELECT x.*,
         (SELECT COUNT(*)::int FROM submissions sb
          WHERE sb.assignment_id = x.id AND sb.submitted_at IS NOT NULL) AS "submittedCount",
         (SELECT COUNT(*)::int FROM submissions sb
          WHERE sb.assignment_id = x.id AND sb.grade IS NOT NULL) AS "gradedCount"
       FROM (${ASSIGNMENT} WHERE a.class_id = $1) x
       ORDER BY x."dueAt" DESC`,
      [classId],
    ),
  );
}

/** The class's homework for one student, each with their submission (or null). */
async function studentAssignments(institutionId, className, studentId) {
  const assignments = await withAttachments(
    await query(
      `${ASSIGNMENT} WHERE a.institution_id = $1 AND c.name = $2 ORDER BY a.due_at`,
      [institutionId, className],
    ),
  );
  const subs = await submissionsOf(assignments.map((a) => a.id), [studentId]);
  return assignments.map((a) => ({ ...a, submission: subs.get(`${a.id}/${studentId}`) ?? null }));
}

/**
 * Submissions of the given assignments and students, with their files:
 * Map "assignmentId/studentId" → { submittedAt, grade, feedback, gradedAt, files }.
 */
async function submissionsOf(assignmentIds, studentIds) {
  if (assignmentIds.length === 0 || studentIds.length === 0) return new Map();
  const subs = await query(
    `SELECT assignment_id, student_id, submitted_at AS "submittedAt",
            grade::float AS grade, feedback, graded_at AS "gradedAt"
     FROM submissions WHERE assignment_id = ANY($1) AND student_id = ANY($2)`,
    [assignmentIds, studentIds],
  );
  const files = await query(
    `SELECT sf.assignment_id, sf.student_id, f.id, f.name, f.mime, f.size_bytes AS size
     FROM submission_files sf JOIN files f ON f.id = sf.file_id
     WHERE sf.assignment_id = ANY($1) AND sf.student_id = ANY($2) ORDER BY f.created_at`,
    [assignmentIds, studentIds],
  );

  return new Map(
    subs.map(({ assignment_id: a, student_id: s, ...sub }) => [
      `${a}/${s}`,
      {
        ...sub,
        files: files
          .filter((f) => f.assignment_id === a && f.student_id === s)
          .map(({ assignment_id: _, student_id: __, ...f }) => f),
      },
    ]),
  );
}

const FIELDS = [
  "subjectId", "type", "title", "description", "dueAt", "allowsLate", "acceptsFiles", "maxGrade",
];

async function insertAssignment(tx, institutionId, classId, body, createdBy) {
  const { id } = await tx.queryOne(
    `INSERT INTO assignments (institution_id, class_id, subject_id, type, title,
       description, due_at, allows_late, accepts_files, max_grade, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id`,
    [institutionId, classId, ...FIELDS.map((f) => body[f]), createdBy],
  );
  await setAttachments(tx, id, body.fileIds);
  return id;
}

async function updateAssignment(tx, id, body) {
  await tx.query(
    `UPDATE assignments SET subject_id = $2, type = $3, title = $4, description = $5,
       due_at = $6, allows_late = $7, accepts_files = $8, max_grade = $9
     WHERE id = $1`,
    [id, ...FIELDS.map((f) => body[f])],
  );
  await setAttachments(tx, id, body.fileIds);
}

async function setAttachments(tx, assignmentId, fileIds) {
  await tx.query("DELETE FROM assignment_attachments WHERE assignment_id = $1", [assignmentId]);
  for (const fileId of fileIds) {
    await tx.query(
      "INSERT INTO assignment_attachments (assignment_id, file_id) VALUES ($1, $2)",
      [assignmentId, fileId],
    );
  }
}

function deleteAssignment(id) {
  return query("DELETE FROM assignments WHERE id = $1", [id]);
}

/** Hands in (again): replaces the files and the time. */
async function submit(tx, assignmentId, studentId, fileIds) {
  await tx.query(
    `INSERT INTO submissions (assignment_id, student_id, submitted_at) VALUES ($1, $2, now())
     ON CONFLICT (assignment_id, student_id) DO UPDATE SET submitted_at = now()`,
    [assignmentId, studentId],
  );
  await tx.query(
    "DELETE FROM submission_files WHERE assignment_id = $1 AND student_id = $2",
    [assignmentId, studentId],
  );
  for (const fileId of fileIds) {
    await tx.query(
      "INSERT INTO submission_files (assignment_id, student_id, file_id) VALUES ($1, $2, $3)",
      [assignmentId, studentId, fileId],
    );
  }
}

/** Grades the student (also work handed in on paper). */
function grade(assignmentId, studentId, { grade, feedback }) {
  return query(
    `INSERT INTO submissions (assignment_id, student_id, grade, feedback, graded_at)
     VALUES ($1, $2, $3, $4, now())
     ON CONFLICT (assignment_id, student_id)
     DO UPDATE SET grade = $3, feedback = $4, graded_at = now()`,
    [assignmentId, studentId, grade, feedback || null],
  );
}

async function hasAnyAssignments() {
  return Boolean(await queryOne("SELECT 1 AS yes FROM assignments LIMIT 1"));
}

module.exports = {
  findAssignment,
  classAssignments,
  studentAssignments,
  submissionsOf,
  insertAssignment,
  updateAssignment,
  deleteAssignment,
  submit,
  grade,
  hasAnyAssignments,
};
