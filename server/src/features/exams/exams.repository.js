// SQL for exams and their scores.
const { query, queryOne } = require("../../db/database");

// One exam as the app shows it. NUMERIC comes back as text, so scores are
// cast to float.
const EXAM = `
  SELECT e.id, e.class_id AS "classId", c.name AS "className",
         e.type, e.title, e.date::text AS date,
         to_char(e.start_time, 'HH24:MI') AS "startTime",
         e.duration_minutes AS "durationMinutes", e.room, e.topics,
         e.max_score::float AS "maxScore", e.published_at IS NOT NULL AS published,
         s.id AS "subjectId", s.name AS "subjectName", s.icon, s.color,
         t.name AS "teacherName"
  FROM exams e
  JOIN classes c ON c.id = e.class_id
  JOIN subjects s ON s.id = e.subject_id
  LEFT JOIN class_subjects cs ON cs.class_id = e.class_id AND cs.subject_id = e.subject_id
  LEFT JOIN users t ON t.id = cs.teacher_id`;

function findExam(institutionId, examId) {
  return queryOne(`${EXAM} WHERE e.institution_id = $1 AND e.id = $2`, [
    institutionId,
    examId,
  ]);
}

/** A class's exams, optionally of one subject, with how many are scored. */
function classExams(classId, subjectId = null) {
  return query(
    `SELECT x.*, (SELECT COUNT(*)::int FROM exam_scores es WHERE es.exam_id = x.id)
                   AS "scoredCount"
     FROM (${EXAM} WHERE e.class_id = $1 AND ($2::text IS NULL OR e.subject_id = $2)) x
     ORDER BY x.date, x."startTime"`,
    [classId, subjectId],
  );
}

/** A student's exams (their class's), with their own score once published. */
function studentExams(institutionId, className, studentId) {
  return query(
    `SELECT x.*,
            CASE WHEN x.published THEN
              (SELECT es.score::float FROM exam_scores es
               WHERE es.exam_id = x.id AND es.student_id = $3)
            END AS score
     FROM (${EXAM} WHERE e.institution_id = $1 AND c.name = $2) x
     ORDER BY x.date, x."startTime"`,
    [institutionId, className, studentId],
  );
}

function insertExam(institutionId, classId, fields, createdBy) {
  return queryOne(
    `INSERT INTO exams (institution_id, class_id, subject_id, type, title, date,
                        start_time, duration_minutes, room, topics, max_score, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING id`,
    [
      institutionId, classId, fields.subjectId, fields.type, fields.title, fields.date,
      fields.startTime, fields.durationMinutes, fields.room, fields.topics,
      fields.maxScore, createdBy,
    ],
  );
}

function updateExam(examId, fields) {
  return query(
    `UPDATE exams SET subject_id = $2, type = $3, title = $4, date = $5,
            start_time = $6, duration_minutes = $7, room = $8, topics = $9,
            max_score = $10
     WHERE id = $1`,
    [
      examId, fields.subjectId, fields.type, fields.title, fields.date,
      fields.startTime, fields.durationMinutes, fields.room, fields.topics,
      fields.maxScore,
    ],
  );
}

function deleteExam(examId) {
  return query("DELETE FROM exams WHERE id = $1", [examId]);
}

/** Student ID → score. */
async function scoresOf(examId) {
  const rows = await query(
    "SELECT student_id, score::float AS score FROM exam_scores WHERE exam_id = $1",
    [examId],
  );
  return new Map(rows.map((r) => [r.student_id, r.score]));
}

async function highestScore(examId) {
  const row = await queryOne(
    "SELECT MAX(score)::float AS max FROM exam_scores WHERE exam_id = $1",
    [examId],
  );
  return row.max;
}

/** Replaces the exam's scores ({ studentId: score | null }) and publishes. */
async function saveScores(tx, examId, scores) {
  for (const [studentId, score] of Object.entries(scores)) {
    if (score === null) {
      await tx.query("DELETE FROM exam_scores WHERE exam_id = $1 AND student_id = $2", [
        examId,
        studentId,
      ]);
    } else {
      await tx.query(
        `INSERT INTO exam_scores (exam_id, student_id, score) VALUES ($1, $2, $3)
         ON CONFLICT (exam_id, student_id) DO UPDATE SET score = $3`,
        [examId, studentId, score],
      );
    }
  }
  await tx.query(
    "UPDATE exams SET published_at = COALESCE(published_at, now()) WHERE id = $1",
    [examId],
  );
}

/**
 * Each student's average (0–100) in one subject of a class, from published
 * scores, weighted by each exam's max: { studentId: average }.
 */
async function subjectAverages(classId, subjectId) {
  const rows = await query(
    `SELECT es.student_id, 100 * SUM(es.score) / SUM(e.max_score) AS average
     FROM exam_scores es JOIN exams e ON e.id = es.exam_id
     WHERE e.class_id = $1 AND e.subject_id = $2 AND e.published_at IS NOT NULL
     GROUP BY es.student_id`,
    [classId, subjectId],
  );
  return Object.fromEntries(rows.map((r) => [r.student_id, Number(r.average)]));
}

async function hasAnyExams() {
  return Boolean(await queryOne("SELECT 1 AS yes FROM exams LIMIT 1"));
}

module.exports = {
  findExam,
  classExams,
  studentExams,
  insertExam,
  updateExam,
  deleteExam,
  scoresOf,
  highestScore,
  saveScores,
  subjectAverages,
  hasAnyExams,
};
