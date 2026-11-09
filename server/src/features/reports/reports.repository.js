// School numbers for the office, worked out from the real data: attendance
// marks, published exam scores, homework hand-ins and bus trips.
const { query, queryOne } = require("../../db/database");
const config = require("../../config");

/** How many students, teachers, parents and classes the school has. */
function counts(institutionId) {
  return queryOne(
    `SELECT
       COUNT(*) FILTER (WHERE role = 'student' AND is_active)::int AS students,
       COUNT(*) FILTER (WHERE role = 'teacher' AND is_active)::int AS teachers,
       COUNT(*) FILTER (WHERE role = 'parent' AND is_active)::int AS parents,
       (SELECT COUNT(*)::int FROM classes WHERE institution_id = $1) AS classes
     FROM users WHERE institution_id = $1`,
    [institutionId],
  );
}

/**
 * Today's students: present (at least one lesson not absent) and absent
 * (absent from every lesson marked so far).
 */
async function presentToday(institutionId, date) {
  return queryOne(
    `SELECT COUNT(*) FILTER (WHERE NOT all_absent)::int AS present,
            COUNT(*) FILTER (WHERE all_absent)::int AS absent
     FROM (
       SELECT m.student_id, bool_and(m.status = 'absent') AS all_absent
       FROM attendance_marks m JOIN classes c ON c.id = m.class_id
       WHERE c.institution_id = $1 AND m.date = $2
       GROUP BY m.student_id
     ) d`,
    [institutionId, date],
  );
}

/** Classes with a lesson that already started today but has no attendance. */
async function classesMissingAttendance(institutionId, date, weekday, time) {
  const rows = await query(
    `SELECT DISTINCT c.name FROM timetable_slots t
     JOIN classes c ON c.id = t.class_id
     JOIN periods p ON p.institution_id = c.institution_id AND p.number = t.period
     WHERE c.institution_id = $1 AND t.weekday = $3 AND p.start_time <= $4::time
       AND NOT EXISTS (SELECT 1 FROM attendance_marks m
                       WHERE m.class_id = c.id AND m.date = $2 AND m.period = t.period)
     ORDER BY c.name`,
    [institutionId, date, weekday, time],
  );
  return rows.map((r) => r.name);
}

// ---------- Insights for a date range [from, to] ----------

/** Rate (0–1) of lesson marks that weren't absent, overall and by day / class. */
async function attendance(institutionId, from, to) {
  const marks = `FROM attendance_marks m JOIN classes c ON c.id = m.class_id
                 WHERE c.institution_id = $1 AND m.date BETWEEN $2 AND $3`;
  const rate = "AVG(CASE WHEN m.status = 'absent' THEN 0 ELSE 1 END)::float";
  const params = [institutionId, from, to];

  const total = await queryOne(`SELECT ${rate} AS rate ${marks}`, params);
  // ISO day of week: 1 = Monday ... 7 = Sunday, like Dart.
  const byDay = await query(
    `SELECT EXTRACT(ISODOW FROM m.date)::int AS weekday, ${rate} AS rate ${marks}
     GROUP BY 1 ORDER BY 1`,
    params,
  );
  const byClass = await query(
    `SELECT c.name AS label, ${rate} AS rate ${marks} GROUP BY c.name ORDER BY rate`,
    params,
  );
  return { rate: total.rate, byDay, byClass };
}

/** Published scores as percentages: average, pass rate (≥ 50) and by subject. */
async function grades(institutionId, from, to) {
  const scores = `FROM exam_scores es JOIN exams e ON e.id = es.exam_id
                  JOIN subjects s ON s.id = e.subject_id
                  WHERE e.institution_id = $1 AND e.published_at IS NOT NULL
                    AND e.date BETWEEN $2 AND $3`;
  const percent = "100.0 * es.score / e.max_score";
  const params = [institutionId, from, to];

  const total = await queryOne(
    `SELECT AVG(${percent})::float AS average,
            AVG(CASE WHEN ${percent} >= 50 THEN 1 ELSE 0 END)::float AS "passRate"
     ${scores}`,
    params,
  );
  const bySubject = await query(
    `SELECT s.name AS label, AVG(${percent})::float AS value ${scores}
     GROUP BY s.name ORDER BY value`,
    params,
  );
  return { ...total, bySubject };
}

/** Homework due in the range and the share of it handed in. */
function homework(institutionId, from, to) {
  return queryOne(
    `SELECT COUNT(*)::int AS given,
            COALESCE(SUM(handed_in)::float / NULLIF(SUM(expected), 0), 0) AS "submissionRate"
     FROM (
       SELECT a.id,
              (SELECT COUNT(*) FROM submissions sb
               WHERE sb.assignment_id = a.id AND sb.submitted_at IS NOT NULL) AS handed_in,
              (SELECT COUNT(*) FROM users u
               WHERE u.institution_id = a.institution_id AND u.role = 'student'
                 AND u.class_name = c.name AND u.is_active) AS expected
       FROM assignments a JOIN classes c ON c.id = a.class_id
       WHERE a.institution_id = $1 AND (a.due_at AT TIME ZONE $4)::date BETWEEN $2 AND $3
     ) x`,
    [institutionId, from, to, config.timeZone],
  );
}

/** Finished bus trips; on time = at most 5 minutes late. */
function trips(institutionId, from, to) {
  return queryOne(
    `SELECT COUNT(*)::int AS done,
            COALESCE(AVG(CASE WHEN t.delay_minutes <= 5 THEN 1 ELSE 0 END), 1)::float AS "onTimeRate",
            COALESCE(ROUND(AVG(t.delay_minutes) FILTER (WHERE t.delay_minutes > 0)), 0)::int
              AS "averageDelay"
     FROM bus_trips t JOIN bus_routes r ON r.id = t.route_id
     WHERE r.institution_id = $1 AND t.ended_at IS NOT NULL
       AND t.trip_date BETWEEN $2 AND $3`,
    [institutionId, from, to],
  );
}

module.exports = {
  counts,
  presentToday,
  classesMissingAttendance,
  attendance,
  grades,
  homework,
  trips,
};
