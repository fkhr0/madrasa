const express = require("express");
const { HttpError, validate, isoDate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const academics = require("../academics/academics.repository");
const institution = require("../institution/institution.repository");
const timetable = require("../timetable/timetable.repository");
const { notify, withParents } = require("../notifications/notify");
const { personOr404 } = require("../users/access");
const { today, addDays, weekdayOf, schoolCalendar } = require("./school-days");
const { studentDays } = require("./student-days");
const repo = require("./attendance.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const TEACHER_DAYS_BACK = 7;

router.get("/classes/:id/lessons", requireRole("teacher", "admin"), async (req, res) => {
  const schoolClass = await classOr404(req);
  const date = req.query.date ? validate(isoDate, req.query.date) : today();
  const calendar = await calendarOr404(req);

  const isSchoolDay = calendar.isSchoolDay(date);
  const taken = await repo.takenPeriods(schoolClass.id, date);
  const lessons = isSchoolDay
    ? (await timetable.classWeek(schoolClass.id)).filter(
        (l) =>
          l.weekday === weekdayOf(date) &&
          (req.user.role === "admin" || l.teacherId === req.user.id),
      )
    : [];

  res.json({
    date,
    className: schoolClass.name,
    isSchoolDay,
    lessons: lessons.map((l) => ({
      period: l.period,
      start: l.start,
      end: l.end,
      subjectName: l.subjectName,
      teacherName: l.teacherName,
      taken: taken.has(l.period),
    })),
  });
});

router.get(
  "/classes/:id/lessons/:date/:period",
  requireRole("teacher", "admin"),
  async (req, res) => {
    const { schoolClass, lesson, date } = await lessonOr4xx(req);
    res.json(await lessonSheet(schoolClass.id, lesson, date));
  },
);

router.put(
  "/classes/:id/lessons/:date/:period",
  requireRole("teacher", "admin"),
  async (req, res) => {
    const { schoolClass, lesson, date } = await lessonOr4xx(req);
    const { marks } = validate(
      z.object({
        marks: z.record(z.string(), z.enum(["present", "late", "absent"])),
      }),
      req.body,
    );

    const students = await repo.classStudents(schoolClass.id);
    const missing = students.filter((s) => !marks[s.id]);
    if (missing.length > 0) {
      throw new HttpError(400, "Mark every student ({0} is missing).", [missing[0].name]);
    }
    const known = new Set(students.map((s) => s.id));
    if (Object.keys(marks).some((id) => !known.has(id))) {
      throw new HttpError(400, "Only students of {0} can be marked.", [schoolClass.name]);
    }

    const before = await repo.lessonMarks(schoolClass.id, date, lesson.period);
    await transaction((tx) =>
      repo.saveLessonMarks(
        tx,
        {
          classId: schoolClass.id,
          date,
          period: lesson.period,
          subjectName: lesson.subjectName,
          markedBy: req.user.id,
        },
        marks,
      ),
    );

    const excused = await repo.excusedOn(students.map((s) => s.id), date);
    const newlyAbsent = students.filter(
      (s) =>
        marks[s.id] === "absent" && before.get(s.id) !== "absent" && !excused.has(s.id),
    );
    for (const student of newlyAbsent) {
      await notify(req.user.institutionId, await withParents([student.id]), {
        type: "attendance",
        title: msg("{0} was absent", student.name),
        body: msg("{0}, period {1} ({2}).", lesson.subjectName, lesson.period, date),
        route: "/attendance",
      });
    }

    const counts = { present: 0, late: 0, absent: 0 };
    for (const status of Object.values(marks)) counts[status]++;
    await log(req.user, {
      kind: "attendance",
      action: before.size > 0 ? "attendance.changed" : "attendance.taken",
      summary:
        msg(
          before.size > 0
            ? "changed attendance for {0}, period {1} ({2}) on {3}: {4} present, {5} late, {6} absent"
            : "took attendance for {0}, period {1} ({2}) on {3}: {4} present, {5} late, {6} absent",
          schoolClass.name, lesson.period, lesson.subjectName, date,
          counts.present, counts.late, counts.absent,
        ),
      classId: schoolClass.id,
      route: `/classes/${schoolClass.id}/attendance`,
    });
    for (const s of students) {
      const status = marks[s.id];
      if (status === "present" || status === before.get(s.id)) continue;
      await log(req.user, {
        kind: "attendance",
        action: "attendance.marked",
        summary: msg("marked {0} {1} in {2} (period {3}, {4})", s.name, msg(status), lesson.subjectName, lesson.period, date),
        classId: schoolClass.id,
        studentIds: [s.id],
        route: "/attendance",
      });
    }

    res.json(await lessonSheet(schoolClass.id, lesson, date));
  },
);

router.get("/students/:id", async (req, res) => {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student") throw new HttpError(404, "Person not found.");

  const year = await institution.findCurrentYear(student.institutionId);
  if (!year) return res.json({ from: null, to: null, days: [] });
  const day = today();
  const terms = await institution.findTerms(year.id);
  const term = terms.find((t) => day >= t.start && day <= t.end);
  const from = term?.start ?? year.start;
  const to = day < year.end ? day : year.end;

  res.json({
    from,
    to,
    days: studentDays(
      await repo.studentMarks(student.id, from, to),
      await repo.studentExcuses(student.id, from, to),
    ),
  });
});

router.get("/students/:id/excuses/planned", async (req, res) => {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student") throw new HttpError(404, "Person not found.");
  const year = await institution.findCurrentYear(student.institutionId);
  const from = addDays(today(), 1);
  res.json(year ? await repo.studentExcuses(student.id, from, year.end) : []);
});

router.put("/students/:id/excuses/:date", requireRole("admin"), async (req, res) => {
  const student = await studentOfMySchool(req);
  const date = validate(isoDate, req.params.date);
  const { note } = validate(
    z.object({ note: z.string().trim().max(200).default("") }),
    req.body,
  );
  if (!(await calendarOr404(req)).isSchoolDay(date)) {
    throw new HttpError(400, "That day is not a school day.");
  }

  await repo.setExcuse(student.id, date, note, req.user.id);
  await log(req.user, {
    kind: "attendance",
    action: "attendance.excused",
    summary: msg("excused {0} on {1}{2}", student.name, date, note ? `: ${note}` : ""),
    studentIds: [student.id],
    route: "/attendance",
  });
  res.status(204).end();
});

router.delete("/students/:id/excuses/:date", requireRole("admin"), async (req, res) => {
  const student = await studentOfMySchool(req);
  const date = validate(isoDate, req.params.date);
  if (!(await repo.deleteExcuse(student.id, date))) {
    throw new HttpError(404, "That day is not excused.");
  }
  await log(req.user, {
    kind: "attendance",
    action: "attendance.unexcused",
    summary: msg("took back the excuse of {0} on {1}", student.name, date),
    studentIds: [student.id],
    route: "/attendance",
  });
  res.status(204).end();
});

async function classOr404(req) {
  const schoolClass = await academics.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

async function calendarOr404(req) {
  const calendar = await schoolCalendar(req.user.institutionId);
  if (!calendar) throw new HttpError(404, "The school has no study year yet.");
  return calendar;
}

async function lessonOr4xx(req) {
  const schoolClass = await classOr404(req);
  const date = validate(isoDate, req.params.date);
  const period = Number(req.params.period);

  if (date > today()) throw new HttpError(400, "Attendance can't be taken ahead.");
  if (!(await calendarOr404(req)).isSchoolDay(date)) {
    throw new HttpError(400, "That day is not a school day.");
  }
  const lesson = (await timetable.classWeek(schoolClass.id)).find(
    (l) => l.weekday === weekdayOf(date) && l.period === period,
  );
  if (!lesson) throw new HttpError(404, "There is no lesson then.");

  if (req.user.role === "teacher") {
    if (lesson.teacherId !== req.user.id) {
      throw new HttpError(403, "Only the {0} teacher marks this lesson.", [lesson.subjectName]);
    }
    if (date < addDays(today(), -TEACHER_DAYS_BACK)) {
      throw new HttpError(403, "That lesson is more than a week ago. Ask the school office to change it.",
      );
    }
  }
  return { schoolClass, lesson, date };
}

async function lessonSheet(classId, lesson, date) {
  const marks = await repo.lessonMarks(classId, date, lesson.period);
  const students = await repo.classStudents(classId);
  return {
    lesson: {
      date,
      period: lesson.period,
      start: lesson.start,
      end: lesson.end,
      subjectName: lesson.subjectName,
      teacherName: lesson.teacherName,
    },
    students: students.map((s) => ({ ...s, status: marks.get(s.id) ?? null })),
  };
}

async function studentOfMySchool(req) {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student") throw new HttpError(404, "Person not found.");
  return student;
}

module.exports = router;
