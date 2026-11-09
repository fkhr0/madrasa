// The weekly timetable. Everyone reads their own week; the administrator sets
// the bell times and places each class's lessons.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const academics = require("../academics/academics.repository");
const institution = require("../institution/institution.repository");
const { personOr404 } = require("../users/access");
const repo = require("./timetable.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");
const { cachedForSchool } = require("../../common/cache");

const router = express.Router();
router.use(requireAuth);

const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "use HH:MM");

// ---------- Bell times ----------

// GET /timetable/periods -> [{ number, start, end }]
router.get("/periods", async (req, res) => {
  res.json(await periodsOf(req.user.institutionId));
});

const periodsOf = (school) => cachedForSchool(school, "periods", () => repo.listPeriods(school));

// PUT /timetable/periods { periods: [{ start, end }], removeLessons? } -> periods
// Cutting periods that hold lessons is refused (409) unless removeLessons is
// true, so the app can ask first.
router.put("/periods", requireRole("admin"), async (req, res) => {
  const { periods, removeLessons } = validate(
    z.object({
      periods: z.array(z.object({ start: time, end: time })).min(1).max(12),
      removeLessons: z.boolean().default(false),
    }),
    req.body,
  );
  periods.forEach((p, i) => {
    if (p.end <= p.start) {
      throw new HttpError(400, "Period {0} must end after it starts.", [i + 1]);
    }
    if (i > 0 && p.start < periods[i - 1].end) {
      throw new HttpError(400, "Period {0} starts before period {1} ends.", [i + 1, i]);
    }
  });

  const institutionId = req.user.institutionId;
  const lost = await repo.countLessonsAfter(institutionId, periods.length);
  if (lost > 0 && !removeLessons) {
    throw new HttpError(
      409,
      lost === 1
        ? "1 lesson is placed after period {1}. Remove it too?"
        : "{0} lessons are placed after period {1}. Remove them too?",
      [lost, periods.length],
    );
  }

  await log(req.user, {
    kind: "academics",
    action: "timetable.bellTimes",
    summary: lost > 0
      ? msg("changed the bell times ({0} periods, {1} lessons removed)", periods.length, lost)
      : msg("changed the bell times ({0} periods)", periods.length),
  });
  await transaction(async (tx) => {
    await repo.deleteLessonsAfter(tx, institutionId, periods.length);
    await repo.replacePeriods(tx, institutionId, periods);
  });
  res.json(await repo.listPeriods(institutionId));
});

// ---------- Someone's week ----------

// GET /timetable/people/:id/week -> { periods, lessons }
// A student's class lessons or a teacher's teaching lessons. Allowed for
// the person, their parents, and the administrator of their school.
router.get("/people/:id/week", async (req, res) => {
  const person = await personOr404(req.user, req.params.id);

  const school = person.institutionId;
  // Every student of a class shares one cached week.
  let lessons = [];
  if (person.role === "student" && person.className) {
    lessons = await cachedForSchool(school, `week:class:${person.className}`, () =>
      repo.studentWeek(school, person.className),
    );
  } else if (person.role === "teacher") {
    lessons = await cachedForSchool(school, `week:teacher:${person.id}`, () =>
      repo.teacherWeek(person.id),
    );
  }
  res.json({ periods: await periodsOf(school), lessons });
});

// ---------- A class's week (administrator) ----------

const admin = express.Router();
admin.use(requireRole("admin"));
router.use("/classes", admin);

// GET /timetable/classes/:id -> { periods, workingDays, lessons }
admin.get("/:id", async (req, res) => {
  const schoolClass = await classOr404(req);
  res.json(await classTimetable(req.user.institutionId, schoolClass.id));
});

// PUT /timetable/classes/:id/lessons/:weekday/:period { subjectId, room }
//   -> class timetable. Refused when the subject's teacher is busy then.
admin.put("/:id/lessons/:weekday/:period", async (req, res) => {
  const schoolClass = await classOr404(req);
  const { weekday, period } = await slotOr400(req);
  const body = validate(
    z.object({
      subjectId: z.string(),
      room: z.string().trim().max(40).default(""),
    }),
    req.body,
  );

  const subject = schoolClass.subjects.find((s) => s.subjectId === body.subjectId);
  if (!subject) {
    throw new HttpError(400, "{0} doesn't study this subject.", [schoolClass.name]);
  }
  const [clash] = await repo.teacherClashes(subject.teacherId, schoolClass.id, [
    { weekday, period },
  ]);
  if (clash) {
    throw new HttpError(409, "{0} already teaches {1} in period {2} that day.", [subject.teacherName, clash.className, period],
    );
  }

  await repo.setLesson(schoolClass.id, weekday, period, body);
  await log(req.user, {
    kind: "academics",
    action: "timetable.lesson",
    summary: msg("put {0} in {1}'s timetable (day {2}, period {3})", subject.subjectName, schoolClass.name, weekday, period),
    classId: schoolClass.id,
  });
  res.json(await classTimetable(req.user.institutionId, schoolClass.id));
});

// DELETE /timetable/classes/:id/lessons/:weekday/:period -> class timetable
admin.delete("/:id/lessons/:weekday/:period", async (req, res) => {
  const schoolClass = await classOr404(req);
  const { weekday, period } = await slotOr400(req);
  if (!(await repo.deleteLesson(schoolClass.id, weekday, period))) {
    throw new HttpError(404, "There is no lesson then.");
  }
  await log(req.user, {
    kind: "academics",
    action: "timetable.freed",
    summary: msg("freed period {0} (day {1}) in {2}'s timetable", period, weekday, schoolClass.name),
    classId: schoolClass.id,
  });
  res.json(await classTimetable(req.user.institutionId, schoolClass.id));
});

// ---------- helpers ----------

async function classOr404(req) {
  const schoolClass = await academics.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

/** The day and period from the URL, checked against the school's week. */
async function slotOr400(req) {
  const weekday = Number(req.params.weekday);
  const period = Number(req.params.period);
  const institutionId = req.user.institutionId;

  const year = await institution.findCurrentYear(institutionId);
  if (!year?.working_days.includes(weekday)) {
    throw new HttpError(400, "That day is not a study day.");
  }
  const periods = await repo.listPeriods(institutionId);
  if (!periods.some((p) => p.number === period)) {
    throw new HttpError(400, "That period doesn't exist. Check the bell times.");
  }
  return { weekday, period };
}

async function classTimetable(institutionId, classId) {
  const year = await institution.findCurrentYear(institutionId);
  return {
    periods: await repo.listPeriods(institutionId),
    workingDays: year?.working_days ?? [],
    lessons: await repo.classWeek(classId),
  };
}

module.exports = router;
