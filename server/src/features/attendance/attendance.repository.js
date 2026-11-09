// SQL for attendance marks and excused days.
const { query, queryOne } = require("../../db/database");

/** Active students of a class, by name: [{ id, name }]. */
function classStudents(classId) {
  return query(
    `SELECT u.id, u.name FROM users u
     JOIN classes c ON c.institution_id = u.institution_id AND c.name = u.class_name
     WHERE c.id = $1 AND u.role = 'student' AND u.is_active
     ORDER BY u.name`,
    [classId],
  );
}

/** Periods of [date] that already have marks for the class. */
async function takenPeriods(classId, date) {
  const rows = await query(
    `SELECT DISTINCT period FROM attendance_marks WHERE class_id = $1 AND date = $2`,
    [classId, date],
  );
  return new Set(rows.map((r) => r.period));
}

/** Student ID → status for one lesson. */
async function lessonMarks(classId, date, period) {
  const rows = await query(
    `SELECT student_id, status FROM attendance_marks
     WHERE class_id = $1 AND date = $2 AND period = $3`,
    [classId, date, period],
  );
  return new Map(rows.map((r) => [r.student_id, r.status]));
}

/** Saves one lesson's marks ({ studentId: status }), replacing old ones. */
async function saveLessonMarks(tx, { classId, date, period, subjectName, markedBy }, marks) {
  for (const [studentId, status] of Object.entries(marks)) {
    await tx.query(
      `INSERT INTO attendance_marks
         (student_id, date, period, status, class_id, subject_name, marked_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (student_id, date, period) DO UPDATE
       SET status = $4, class_id = $5, subject_name = $6, marked_by = $7,
           marked_at = now()`,
      [studentId, date, period, status, classId, subjectName, markedBy],
    );
  }
}

/** A student's marks between two dates: [{ date, period, status, subjectName }]. */
function studentMarks(studentId, from, to) {
  return query(
    `SELECT date::text AS date, period, status, subject_name AS "subjectName"
     FROM attendance_marks
     WHERE student_id = $1 AND date BETWEEN $2 AND $3
     ORDER BY date DESC, period`,
    [studentId, from, to],
  );
}

function studentExcuses(studentId, from, to) {
  return query(
    `SELECT date::text AS date, note FROM attendance_excuses
     WHERE student_id = $1 AND date BETWEEN $2 AND $3
     ORDER BY date`,
    [studentId, from, to],
  );
}

/** Which of [studentIds] the office excused on [date]. */
async function excusedOn(studentIds, date) {
  if (studentIds.length === 0) return new Set();
  const rows = await query(
    "SELECT student_id FROM attendance_excuses WHERE student_id = ANY($1) AND date = $2",
    [studentIds, date],
  );
  return new Set(rows.map((r) => r.student_id));
}

function setExcuse(studentId, date, note, createdBy) {
  return query(
    `INSERT INTO attendance_excuses (student_id, date, note, created_by)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (student_id, date) DO UPDATE SET note = $3, created_by = $4`,
    [studentId, date, note, createdBy],
  );
}

async function deleteExcuse(studentId, date) {
  const rows = await query(
    "DELETE FROM attendance_excuses WHERE student_id = $1 AND date = $2 RETURNING date",
    [studentId, date],
  );
  return rows.length > 0;
}

/**
 * Attendance rate (0–100) of each student of a class in one subject's
 * lessons: { studentId: rate }. Students without marks are left out.
 */
async function subjectRates(classId, subjectName) {
  const rows = await query(
    `SELECT student_id,
            100.0 * COUNT(*) FILTER (WHERE status <> 'absent') / COUNT(*) AS rate
     FROM attendance_marks
     WHERE class_id = $1 AND subject_name = $2
     GROUP BY student_id`,
    [classId, subjectName],
  );
  return Object.fromEntries(rows.map((r) => [r.student_id, Number(r.rate)]));
}

async function hasAnyMarks() {
  return Boolean(await queryOne("SELECT 1 AS yes FROM attendance_marks LIMIT 1"));
}

module.exports = {
  classStudents,
  takenPeriods,
  lessonMarks,
  saveLessonMarks,
  studentMarks,
  studentExcuses,
  excusedOn,
  setExcuse,
  deleteExcuse,
  subjectRates,
  hasAnyMarks,
};
