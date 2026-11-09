// The office's numbers: today at school and statistics for a week, month
// or term, all from the real data. (Who did what: GET /activity.)
const express = require("express");
const { validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const institution = require("../institution/institution.repository");
const { today, timeNow, addDays, weekdayOf } = require("../attendance/school-days");
const repo = require("./reports.repository");
const { t } = require("../../i18n");
const { cached } = require("../../common/cache");

const router = express.Router();
router.use(requireAuth, requireRole("admin"));

const DAY_NAMES = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// GET /reports/today
//   -> { students, teachers, parents, classes, presentToday, absentToday, classesMissingAttendance }
router.get("/today", async (req, res) => {
  const id = req.user.institutionId;
  const date = today();
  const time = timeNow();

  const counts = await repo.counts(id);
  const { present, absent } = await repo.presentToday(id, date);
  res.json({
    ...counts,
    presentToday: present,
    absentToday: absent,
    classesMissingAttendance: await repo.classesMissingAttendance(id, date, weekdayOf(date), time),
  });
});

// GET /reports/insights?period=week|month|term -> numbers for the period
// (the shape of the app's InsightsModel; rates are 0–1, grades 0–100).
router.get("/insights", async (req, res) => {
  const period = validate(z.enum(["week", "month", "term"]).default("week"), req.query.period);
  const id = req.user.institutionId;
  const { from, to } = await rangeOf(id, period);
  // A whole term of attendance and grades: worked out once every 5 minutes.
  res.json(
    await cached(`insights:${id}:${from}:${to}:${req.language}`, 5 * 60, () =>
      insights(id, period, from, to),
    ),
  );
});

async function insights(id, period, from, to) {
  // The same number of days just before, for the change in attendance.
  const days = Math.round((new Date(to) - new Date(from)) / 86400000) + 1;
  const before = { from: addDays(from, -days), to: addDays(from, -1) };

  const attendance = await repo.attendance(id, from, to);
  const previous = await repo.attendance(id, before.from, before.to);
  const grades = await repo.grades(id, from, to);
  const homework = await repo.homework(id, from, to);
  const trips = await repo.trips(id, from, to);
  const year = await institution.findCurrentYear(id);
  // Days of the study week, Sunday first (the Iraqi week).
  const studyDays = [...(year?.working_days ?? [7, 1, 2, 3, 4])].sort((a, b) => (a % 7) - (b % 7));

  return {
    period,
    from,
    to,
    attendanceRate: attendance.rate ?? 1,
    attendanceChange:
      attendance.rate == null || previous.rate == null
        ? 0
        : Math.round((attendance.rate - previous.rate) * 1000) / 10,
    attendanceByDay: studyDays.map((d) => ({
      label: t(DAY_NAMES[d]),
      value: attendance.byDay.find((x) => x.weekday === d)?.rate ?? 0,
    })),
    attendanceByClass: attendance.byClass.map((c) => ({ label: c.label, value: c.rate })),
    averageGrade: grades.average ?? 0,
    passRate: grades.passRate ?? 0,
    gradeBySubject: grades.bySubject,
    assignmentsGiven: homework.given,
    submissionRate: homework.submissionRate,
    tripsDone: trips.done,
    onTimeRate: trips.onTimeRate,
    averageDelayMinutes: trips.averageDelay,
  };
}

/** week: since Sunday; month: since the 1st; term: since the term began. */
async function rangeOf(institutionId, period) {
  const to = today();
  if (period === "week") {
    return { from: addDays(to, -(weekdayOf(to) % 7)), to };
  }
  if (period === "month") return { from: `${to.slice(0, 8)}01`, to };

  const year = await institution.findCurrentYear(institutionId);
  const terms = year ? await institution.findTerms(year.id) : [];
  const term = terms.find((t) => to >= t.start && to <= t.end);
  return { from: term?.start ?? year?.start ?? addDays(to, -90), to };
}

module.exports = router;
