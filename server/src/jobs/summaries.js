// Summaries, so nobody has to dig for how things went: 15:00 on school days →
// the office: today at school Thursday 17:00       → each parent, per child:
// the week Each sent once (sent_reminders).
const { query, queryOne } = require("../db/database");
const { notify, admins } = require("../features/notifications/notify");
const reports = require("../features/reports/reports.repository");
const attendance = require("../features/attendance/attendance.repository");
const { studentDays } = require("../features/attendance/student-days");
const { today, addDays, weekdayOf, schoolCalendar } = require("../features/attendance/school-days");
const fees = require("../features/finance/fees");
const config = require("../config");
const { once } = require("./reminders");
const { msg } = require("../i18n");

/** The office's day in one notification (school days only). */
async function dailySummary({ date = today() } = {}) {
  let sent = 0;
  for (const { id } of await query("SELECT id FROM institutions")) {
    const calendar = await schoolCalendar(id);
    if (!calendar?.isSchoolDay(date)) continue;
    if (!(await once(`daily-summary:${id}:${date}`))) continue;

    const { present, absent } = await reports.presentToday(id, date);
    // Lessons of the whole day that never got attendance.
    const missing = await reports.classesMissingAttendance(id, date, weekdayOf(date), "23:59");
    const day = await queryOne(
      `SELECT
         (SELECT COUNT(*)::int FROM assignments
          WHERE institution_id = $1 AND (assigned_at AT TIME ZONE $3)::date = $2) AS homework,
         (SELECT COUNT(*)::int FROM exams
          WHERE institution_id = $1 AND (published_at AT TIME ZONE $3)::date = $2) AS scores,
         (SELECT COALESCE(SUM(amount), 0)::int FROM payments
          WHERE institution_id = $1 AND voided_at IS NULL
            AND (paid_at AT TIME ZONE $3)::date = $2) AS money`,
      [id, date, config.timeZone],
    );

    const rate = present + absent === 0 ? null : Math.round((present / (present + absent)) * 100);
    // One msg() per line: each admin gets them in their language.
    const lines = [
      rate === null
        ? msg("No attendance taken")
        : msg("{0}% present · {1} absent", rate, absent),
      missing.length > 0 && msg("Attendance missing: {0}", missing.join("، ")),
      msg("New homework: {0} · exams scored: {1}", day.homework, day.scores),
      day.money > 0 && msg("{0} received", fees.iqd(day.money)),
    ];

    await notify(id, await admins(id), {
      type: "summary",
      title: msg("Today at school"),
      body: lines,
      route: `/day?date=${date}`,
    });
    sent++;
  }
  return sent;
}

/** Sunday … today (Thursday) of this school week. */
function weekOf(date) {
  return { from: addDays(date, -(weekdayOf(date) % 7)), to: date };
}

/** Each parent, per child: attendance, grades and homework this week, exams next week. */
async function weeklySummary({ date = today() } = {}) {
  const { from, to } = weekOf(date);
  const children = await query(
    `SELECT pc.parent_id AS "parentId", u.id, u.name, u.institution_id AS "institutionId",
            c.id AS "classId"
     FROM parent_children pc
     JOIN users u ON u.id = pc.child_id AND u.is_active
     LEFT JOIN classes c ON c.institution_id = u.institution_id AND c.name = u.class_name`,
  );

  let sent = 0;
  for (const child of children) {
    if (!(await once(`weekly-summary:${child.parentId}:${child.id}:${from}`))) continue;

    const days = studentDays(
      await attendance.studentMarks(child.id, from, to),
      await attendance.studentExcuses(child.id, from, to),
    );
    const count = (status) => days.filter((d) => d.status === status).length;

    const grades = await queryOne(
      `SELECT COUNT(*)::int AS n, AVG(100.0 * es.score / e.max_score)::float AS average
       FROM exam_scores es JOIN exams e ON e.id = es.exam_id
       WHERE es.student_id = $1 AND e.published_at IS NOT NULL
         AND (e.published_at AT TIME ZONE $4)::date BETWEEN $2 AND $3`,
      [child.id, from, to, config.timeZone],
    );
    const homework = await queryOne(
      `SELECT COUNT(*)::int AS given,
              COUNT(sb.submitted_at)::int AS "handedIn"
       FROM assignments a
       LEFT JOIN submissions sb ON sb.assignment_id = a.id AND sb.student_id = $1
       WHERE a.class_id = $2 AND (a.due_at AT TIME ZONE $5)::date BETWEEN $3 AND $4`,
      [child.id, child.classId, from, to, config.timeZone],
    );
    const nextExams = await query(
      `SELECT DISTINCT s.name FROM exams e JOIN subjects s ON s.id = e.subject_id
       WHERE e.class_id = $1 AND e.date BETWEEN $2 AND $3 ORDER BY s.name`,
      [child.classId, addDays(to, 1), addDays(to, 7)],
    );

    const lines = [
      days.length === 0
        ? msg("No attendance taken this week")
        : msg("Attendance: {0} of {1} days", count("present") + count("late"), days.length),
      count("absent") > 0 && msg("Days absent: {0}", count("absent")),
      count("late") > 0 && msg("Late: {0} times", count("late")),
      grades.n > 0 && msg("New grades: {0} · average {1}", grades.n, Math.round(grades.average)),
      homework.given > 0 && msg("Homework handed in: {0} of {1}", homework.handedIn, homework.given),
      nextExams.length > 0 &&
        msg("Exams next week: {0}", nextExams.map((e) => e.name).join("، ")),
    ];

    await notify(child.institutionId, [child.parentId], {
      type: "summary",
      title: msg("{0}'s week", child.name.split(" ")[0]),
      body: lines,
      // The parent's Progress tab.
      route: "/work",
    });
    sent++;
  }
  return sent;
}

module.exports = { dailySummary, weeklySummary, weekOf };
