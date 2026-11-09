// A day at school, for any date, as each role needs it:
//   GET /days/:date/school          office: every period, every class, who took
//                                   attendance and when, the day's totals, "now"
//   GET /days/:date/teacher         a teacher's lessons and their attendance
//   GET /days/:date/students/:id    a student's lessons with their own marks,
//                                   homework, exams and bus (student, parents,
//                                   office)
// What happened that day (who did what) comes from GET /activity?date=.
const express = require("express");
const { HttpError, validate, isoDate } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { query, queryOne } = require("../../db/database");
const config = require("../../config");
const timetable = require("../timetable/timetable.repository");
const { personOr404 } = require("../users/access");
const { today, timeNow, weekdayOf, schoolCalendar } = require("../attendance/school-days");
const { studentDays } = require("../attendance/student-days");
const { t } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

/** Whether a period is over, going on, or still to come (from the school's clock). */
function stateOf(date, period) {
  const day = today();
  if (date < day) return "done";
  if (date > day) return "later";
  const now = timeNow();
  if (now >= period.end) return "done";
  if (now >= period.start) return "now";
  return "later";
}

/**
 * Attendance taken on [date], by class and period:
 * "classId/period" → { takenBy, takenAt, present, late, absent }.
 */
async function takenOn(institutionId, date) {
  const rows = await query(
    `SELECT m.class_id, m.period,
            COUNT(*) FILTER (WHERE m.status = 'present')::int AS present,
            COUNT(*) FILTER (WHERE m.status = 'late')::int AS late,
            COUNT(*) FILTER (WHERE m.status = 'absent')::int AS absent,
            MAX(m.marked_at) AS "takenAt",
            (ARRAY_AGG(u.name ORDER BY m.marked_at DESC))[1] AS "takenBy"
     FROM attendance_marks m
     JOIN classes c ON c.id = m.class_id
     LEFT JOIN users u ON u.id = m.marked_by
     WHERE c.institution_id = $1 AND m.date = $2
     GROUP BY m.class_id, m.period`,
    [institutionId, date],
  );
  return new Map(
    rows.map(({ class_id: classId, period, ...taken }) => [`${classId}/${period}`, taken]),
  );
}

/** The bell periods with each one's lessons (picked by [include]). */
async function periodsWithLessons(institutionId, date, include) {
  const weekday = weekdayOf(date);
  const periods = await timetable.listPeriods(institutionId);
  const taken = await takenOn(institutionId, date);
  const lessons = (
    await query(
      `SELECT t.class_id AS "classId", c.name AS "className", t.period, t.room,
              s.name AS "subjectName", cs.teacher_id AS "teacherId", u.name AS "teacherName"
       FROM timetable_slots t
       JOIN classes c ON c.id = t.class_id
       JOIN subjects s ON s.id = t.subject_id
       JOIN class_subjects cs ON cs.class_id = t.class_id AND cs.subject_id = t.subject_id
       LEFT JOIN users u ON u.id = cs.teacher_id
       WHERE c.institution_id = $1 AND t.weekday = $2
       ORDER BY c.name`,
      [institutionId, weekday],
    )
  ).filter(include);

  return periods.map((p) => ({
    ...p,
    state: stateOf(date, p),
    lessons: lessons
      .filter((l) => l.period === p.number)
      .map(({ period: _, ...l }) => ({ ...l, attendance: taken.get(`${l.classId}/${p.number}`) ?? null })),
  }));
}

async function dayHeader(institutionId, date) {
  const calendar = await schoolCalendar(institutionId);
  const dayOff = calendar ? calendar.dayOffReason(date) : "No study year";
  return { date, isToday: date === today(), isSchoolDay: dayOff === null, dayOff: dayOff && t(dayOff) };
}

// ---------- The office ----------

router.get("/:date/school", requireRole("admin"), async (req, res) => {
  const date = validate(isoDate, req.params.date);
  const id = req.user.institutionId;
  const header = await dayHeader(id, date);
  if (!header.isSchoolDay) return res.json({ ...header, periods: [], totals: null });

  const periods = await periodsWithLessons(id, date, () => true);
  const lessons = periods.flatMap((p) => p.lessons.map((l) => ({ ...l, state: p.state })));
  const students = await queryOne(
    `SELECT COUNT(*) FILTER (WHERE NOT all_absent)::int AS present,
            COUNT(*) FILTER (WHERE all_absent)::int AS absent
     FROM (SELECT m.student_id, bool_and(m.status = 'absent') AS all_absent
           FROM attendance_marks m JOIN classes c ON c.id = m.class_id
           WHERE c.institution_id = $1 AND m.date = $2 GROUP BY m.student_id) d`,
    [id, date],
  );
  const day = await queryOne(
    `SELECT
       (SELECT COUNT(*)::int FROM users WHERE institution_id = $1 AND role = 'student' AND is_active)
         AS students,
       (SELECT COUNT(*)::int FROM attendance_excuses x JOIN users u ON u.id = x.student_id
        WHERE u.institution_id = $1 AND x.date = $2) AS excused,
       (SELECT COUNT(*)::int FROM assignments
        WHERE institution_id = $1 AND (due_at AT TIME ZONE $3)::date = $2) AS "homeworkDue",
       (SELECT COUNT(*)::int FROM exams WHERE institution_id = $1 AND date = $2) AS exams,
       (SELECT COALESCE(SUM(amount), 0)::int FROM payments
        WHERE institution_id = $1 AND voided_at IS NULL AND (paid_at AT TIME ZONE $3)::date = $2)
         AS "moneyReceived"`,
    [id, date, config.timeZone],
  );

  res.json({
    ...header,
    periods,
    totals: {
      ...day,
      present: students.present,
      absent: students.absent,
      lessons: lessons.length,
      lessonsTaken: lessons.filter((l) => l.attendance).length,
      // Lessons that started (or ended) without attendance.
      lessonsMissing: lessons.filter((l) => !l.attendance && l.state !== "later").length,
    },
  });
});

// ---------- A teacher ----------

router.get("/:date/teacher", requireRole("teacher"), async (req, res) => {
  const date = validate(isoDate, req.params.date);
  const id = req.user.institutionId;
  const header = await dayHeader(id, date);
  const periods = header.isSchoolDay
    ? (await periodsWithLessons(id, date, (l) => l.teacherId === req.user.id)).filter(
        (p) => p.lessons.length > 0,
      )
    : [];

  const homework = await query(
    `SELECT a.id, a.title, c.name AS "className",
            (SELECT COUNT(*)::int FROM submissions sb
             WHERE sb.assignment_id = a.id AND sb.submitted_at IS NOT NULL) AS "handedIn",
            (SELECT COUNT(*)::int FROM submissions sb
             WHERE sb.assignment_id = a.id AND sb.submitted_at IS NOT NULL AND sb.grade IS NULL)
              AS "toGrade"
     FROM assignments a JOIN classes c ON c.id = a.class_id
     JOIN class_subjects cs ON cs.class_id = a.class_id AND cs.subject_id = a.subject_id
     WHERE cs.teacher_id = $1 AND (a.due_at AT TIME ZONE $3)::date = $2
     ORDER BY c.name`,
    [req.user.id, date, config.timeZone],
  );
  const exams = await query(
    `SELECT e.id, e.title, c.name AS "className", to_char(e.start_time, 'HH24:MI') AS "startTime",
            e.published_at IS NOT NULL AS published
     FROM exams e JOIN classes c ON c.id = e.class_id
     JOIN class_subjects cs ON cs.class_id = e.class_id AND cs.subject_id = e.subject_id
     WHERE cs.teacher_id = $1 AND e.date = $2 ORDER BY e.start_time`,
    [req.user.id, date],
  );
  res.json({ ...header, periods, homework, exams });
});

// ---------- A student ----------

router.get("/:date/students/:id", async (req, res) => {
  const date = validate(isoDate, req.params.date);
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student") throw new HttpError(404, "Person not found.");
  const header = await dayHeader(student.institutionId, date);

  const classRow = await queryOne(
    "SELECT id FROM classes WHERE institution_id = $1 AND name = $2",
    [student.institutionId, student.className],
  );
  const marks = new Map(
    (
      await query(
        `SELECT m.period, m.status, m.marked_at AS "markedAt", u.name AS "markedBy"
         FROM attendance_marks m LEFT JOIN users u ON u.id = m.marked_by
         WHERE m.student_id = $1 AND m.date = $2`,
        [student.id, date],
      )
    ).map(({ period, ...mark }) => [period, mark]),
  );
  const periods =
    header.isSchoolDay && classRow
      ? (await periodsWithLessons(student.institutionId, date, (l) => l.classId === classRow.id))
          .filter((p) => p.lessons.length > 0)
          .map((p) => ({
            ...p,
            lessons: p.lessons.map(({ attendance: _, ...l }) => ({
              ...l,
              mark: marks.get(p.number) ?? null,
            })),
          }))
      : [];

  // The day as a whole (absent only when absent from every lesson).
  const [summary] = studentDays(
    await query(
      `SELECT date::text AS date, period, status, subject_name AS "subjectName"
       FROM attendance_marks WHERE student_id = $1 AND date = $2`,
      [student.id, date],
    ),
    await query(
      "SELECT date::text AS date, note FROM attendance_excuses WHERE student_id = $1 AND date = $2",
      [student.id, date],
    ),
  );

  const homework = classRow
    ? await query(
        `SELECT a.id, a.title, s.name AS "subjectName",
                sb.submitted_at IS NOT NULL AS "handedIn", sb.grade::float AS grade,
                a.max_grade::float AS "maxGrade"
         FROM assignments a JOIN subjects s ON s.id = a.subject_id
         LEFT JOIN submissions sb ON sb.assignment_id = a.id AND sb.student_id = $1
         WHERE a.class_id = $2 AND (a.due_at AT TIME ZONE $4)::date = $3`,
        [student.id, classRow.id, date, config.timeZone],
      )
    : [];
  const exams = classRow
    ? await query(
        `SELECT e.id, e.title, s.name AS "subjectName", to_char(e.start_time, 'HH24:MI') AS "startTime",
                e.room,
                CASE WHEN e.published_at IS NOT NULL THEN es.score::float END AS score,
                e.max_score::float AS "maxScore"
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         LEFT JOIN exam_scores es ON es.exam_id = e.id AND es.student_id = $1
         WHERE e.class_id = $2 AND e.date = $3 ORDER BY e.start_time`,
        [student.id, classRow.id, date],
      )
    : [];
  const bus = await query(
    `SELECT t.direction, t.started_at AS "startedAt", t.ended_at AS "endedAt",
            $1 = ANY(t.boarded_ids) AS boarded, r.bus_number AS "busNumber"
     FROM bus_trips t JOIN route_students rs ON rs.route_id = t.route_id AND rs.student_id = $1
     JOIN bus_routes r ON r.id = t.route_id
     WHERE t.trip_date = $2 ORDER BY t.started_at`,
    [student.id, date],
  );

  res.json({
    ...header,
    student: { id: student.id, name: student.name, className: student.className },
    day: summary ? { status: summary.status, note: summary.note } : null,
    periods,
    homework,
    exams,
    bus,
  });
});

module.exports = router;
