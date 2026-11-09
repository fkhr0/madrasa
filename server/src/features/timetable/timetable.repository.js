// SQL for bell times and the weekly timetable.
const { query, queryOne } = require("../../db/database");

// ---------- Bell times ----------

/** [{ number, start: "08:00", end: "08:45" }] in order. */
function listPeriods(institutionId) {
  return query(
    `SELECT number, to_char(start_time, 'HH24:MI') AS start,
            to_char(end_time, 'HH24:MI') AS "end"
     FROM periods WHERE institution_id = $1 ORDER BY number`,
    [institutionId],
  );
}

/** Replaces all bell times; numbers follow the list order (1, 2, 3…). */
async function replacePeriods(tx, institutionId, periods) {
  await tx.query("DELETE FROM periods WHERE institution_id = $1", [institutionId]);
  for (const [i, { start, end }] of periods.entries()) {
    await tx.query(
      `INSERT INTO periods (institution_id, number, start_time, end_time)
       VALUES ($1, $2, $3, $4)`,
      [institutionId, i + 1, start, end],
    );
  }
}

/** Lessons placed in periods after [count] (they'd be lost if cut). */
async function countLessonsAfter(institutionId, count) {
  const row = await queryOne(
    `SELECT COUNT(*)::int AS n FROM timetable_slots t
     JOIN classes c ON c.id = t.class_id
     WHERE c.institution_id = $1 AND t.period > $2`,
    [institutionId, count],
  );
  return row.n;
}

function deleteLessonsAfter(tx, institutionId, count) {
  return tx.query(
    `DELETE FROM timetable_slots t USING classes c
     WHERE c.id = t.class_id AND c.institution_id = $1 AND t.period > $2`,
    [institutionId, count],
  );
}

// ---------- Lessons ----------

// One lesson with everything the app shows. Joined to the bell times, so a
// lesson in a period that no longer exists is simply not listed.
const LESSONS = `
  SELECT t.weekday, t.period, t.room,
         to_char(p.start_time, 'HH24:MI') AS start,
         to_char(p.end_time, 'HH24:MI') AS "end",
         t.subject_id AS "subjectId", s.name AS "subjectName", s.icon, s.color,
         cs.teacher_id AS "teacherId", tch.name AS "teacherName",
         c.id AS "classId", c.name AS "className"
  FROM timetable_slots t
  JOIN classes c ON c.id = t.class_id
  JOIN subjects s ON s.id = t.subject_id
  JOIN class_subjects cs ON cs.class_id = t.class_id AND cs.subject_id = t.subject_id
  LEFT JOIN users tch ON tch.id = cs.teacher_id
  JOIN periods p ON p.institution_id = c.institution_id AND p.number = t.period`;

const ORDER = "ORDER BY t.weekday, t.period";

function classWeek(classId) {
  return query(`${LESSONS} WHERE t.class_id = $1 ${ORDER}`, [classId]);
}

/** A student's week: the lessons of the class they are in. */
function studentWeek(institutionId, className) {
  return query(
    `${LESSONS} WHERE c.institution_id = $1 AND c.name = $2 ${ORDER}`,
    [institutionId, className],
  );
}

/** A teacher's week: every lesson of a subject they teach in a class. */
function teacherWeek(teacherId) {
  return query(`${LESSONS} WHERE cs.teacher_id = $1 ${ORDER}`, [teacherId]);
}

/** Adds the lesson, or changes its subject or room. */
function setLesson(classId, weekday, period, { subjectId, room }) {
  return query(
    `INSERT INTO timetable_slots (class_id, weekday, period, subject_id, room)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (class_id, weekday, period)
     DO UPDATE SET subject_id = $4, room = $5`,
    [classId, weekday, period, subjectId, room],
  );
}

async function deleteLesson(classId, weekday, period) {
  const rows = await query(
    `DELETE FROM timetable_slots
     WHERE class_id = $1 AND weekday = $2 AND period = $3 RETURNING class_id`,
    [classId, weekday, period],
  );
  return rows.length > 0;
}

/**
 * Lessons the teacher already has in another class at the same time as
 * [slots] ([{ weekday, period }]). Empty when the teacher is free.
 */
function teacherClashes(teacherId, classId, slots) {
  if (!teacherId || slots.length === 0) return Promise.resolve([]);
  return query(
    `${LESSONS}
     WHERE cs.teacher_id = $1 AND t.class_id <> $2
       AND (t.weekday, t.period) IN (
         SELECT * FROM unnest($3::int[], $4::int[]))
     ${ORDER}`,
    [teacherId, classId, slots.map((s) => s.weekday), slots.map((s) => s.period)],
  );
}

/** Where [subjectId] is placed in the class's week: [{ weekday, period }]. */
function subjectSlots(classId, subjectId) {
  return query(
    `SELECT weekday, period FROM timetable_slots
     WHERE class_id = $1 AND subject_id = $2`,
    [classId, subjectId],
  );
}

module.exports = {
  listPeriods,
  replacePeriods,
  countLessonsAfter,
  deleteLessonsAfter,
  classWeek,
  studentWeek,
  teacherWeek,
  setLesson,
  deleteLesson,
  teacherClashes,
  subjectSlots,
};
