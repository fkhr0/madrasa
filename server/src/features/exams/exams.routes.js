// Exams: a teacher schedules them for the subjects they teach and publishes
// the scores; the administrator can do it for any subject. Students and
// parents see the class's exams and, once published, their own score.
const express = require("express");
const { HttpError, validate, isoDate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const academics = require("../academics/academics.repository");
const { taughtBy, checkTeaches } = require("../academics/teaches");
const attendance = require("../attendance/attendance.repository");
const { notify, withParents } = require("../notifications/notify");
const { personOr404 } = require("../users/access");
const { today, schoolCalendar } = require("../attendance/school-days");
const repo = require("./exams.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const TYPE_NAMES = {
  quiz: "quiz",
  monthly: "monthly exam",
  midYear: "mid-year exam",
  final: "final exam",
};

const examFields = z.object({
  subjectId: z.string(),
  type: z.enum(["quiz", "monthly", "midYear", "final"]),
  title: z.string().trim().min(2).max(80),
  date: isoDate,
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "use HH:MM").default("08:00"),
  durationMinutes: z.number().int().min(5).max(300).default(45),
  room: z.string().trim().max(40).default(""),
  topics: z.array(z.string().trim().min(1).max(80)).max(20).default([]),
  maxScore: z.number().positive().max(1000).default(100),
});

// ---------- A student's exams ----------

// GET /exams/students/:id -> [exam + { score | null }]  (score once published)
router.get("/students/:id", async (req, res) => {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student" || !student.className) return res.json([]);
  res.json(await repo.studentExams(student.institutionId, student.className, student.id));
});

// ---------- A class's exams (teacher of the subject, or administrator) ----------

const staff = requireRole("teacher", "admin");

// GET /exams/classes/:id?subjectId= -> [exam + { scoredCount }]
// A teacher sees the exams of the subjects they teach there.
router.get("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const subjectId = req.query.subjectId ? String(req.query.subjectId) : null;
  const mine = taughtBy(req.user, schoolClass);

  const exams = await repo.classExams(schoolClass.id, subjectId);
  res.json(exams.filter((e) => mine(e.subjectId)));
});

// POST /exams/classes/:id { subjectId, type, title, date, ... } -> exam
// The class's students and their parents are told.
router.post("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const body = validate(examFields, req.body);
  await checkExam(req, schoolClass, body);

  const { id } = await repo.insertExam(req.user.institutionId, schoolClass.id, body, req.user.id);
  const exam = await repo.findExam(req.user.institutionId, id);
  if (exam.date >= today()) {
    const students = await attendance.classStudents(schoolClass.id);
    await notify(req.user.institutionId, await withParents(students.map((s) => s.id)), {
      type: "schedule",
      title: msg("New {0} {1}", exam.subjectName, msg(TYPE_NAMES[exam.type])),
      body: msg("{0} · {1} at {2}", exam.title, exam.date, exam.startTime),
      route: "/exams",
    });
  }
  await log(req.user, {
    kind: "grades",
    action: "exam.scheduled",
    summary: msg("scheduled {0} ({1}) for {2} on {3} at {4}", exam.title, exam.subjectName, exam.className, exam.date, exam.startTime),
    classId: exam.classId,
    route: "/exams",
  });
  res.status(201).json(exam);
});

// PATCH /exams/:examId { ... same fields } -> exam
router.patch("/:examId", staff, async (req, res) => {
  const exam = await examOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, exam.classId);
  checkTeaches(req.user, schoolClass, exam.subjectId);
  const body = validate(examFields, req.body);
  await checkExam(req, schoolClass, body);

  const highest = await repo.highestScore(exam.id);
  if (highest !== null && body.maxScore < highest) {
    throw new HttpError(400, "A student already has {0}. \"Out of\" can't be lower.", [highest]);
  }
  await repo.updateExam(exam.id, body);
  const changed = await repo.findExam(req.user.institutionId, exam.id);
  await log(req.user, {
    kind: "grades",
    action: "exam.changed",
    summary: msg("changed {0} ({1}) for {2}: {3} at {4}", changed.title, changed.subjectName, changed.className, changed.date, changed.startTime),
    classId: changed.classId,
    route: "/exams",
  });
  res.json(changed);
});

// DELETE /exams/:examId -> 204  (its scores go too; the app asks first)
router.delete("/:examId", staff, async (req, res) => {
  const exam = await examOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, exam.classId);
  checkTeaches(req.user, schoolClass, exam.subjectId);
  await repo.deleteExam(exam.id);
  await log(req.user, {
    kind: "grades",
    action: "exam.deleted",
    summary: msg("deleted {0} ({1}) of {2}", exam.title, exam.subjectName, exam.className),
    classId: exam.classId,
  });
  res.status(204).end();
});

// ---------- Scores ----------

// GET /exams/:examId/scores -> { exam, students: [{ id, name, score | null }] }
router.get("/:examId/scores", staff, async (req, res) => {
  const exam = await examOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, exam.classId);
  checkTeaches(req.user, schoolClass, exam.subjectId);
  res.json(await scoreSheet(exam));
});

// PUT /exams/:examId/scores { scores: { studentId: number | null } } -> same as GET
// Saves and publishes. Students whose score is new or changed are told.
router.put("/:examId/scores", staff, async (req, res) => {
  const exam = await examOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, exam.classId);
  checkTeaches(req.user, schoolClass, exam.subjectId);
  const { scores } = validate(
    z.object({ scores: z.record(z.string(), z.number().min(0).nullable()) }),
    req.body,
  );
  if (exam.date > today()) {
    throw new HttpError(400, "The exam hasn't happened yet.");
  }

  const students = await attendance.classStudents(exam.classId);
  const known = new Map(students.map((s) => [s.id, s]));
  for (const [id, score] of Object.entries(scores)) {
    if (!known.has(id)) {
      throw new HttpError(400, "Only students of {0} can get a score.", [exam.className]);
    }
    if (score !== null && score > exam.maxScore) {
      throw new HttpError(400, "{0}: {1} is more than {2}.", [known.get(id).name, score, exam.maxScore]);
    }
  }

  const before = await repo.scoresOf(exam.id);
  await transaction((tx) => repo.saveScores(tx, exam.id, scores));

  for (const [id, score] of Object.entries(scores)) {
    if (score === null || before.get(id) === score) continue;
    await notify(req.user.institutionId, await withParents([id]), {
      type: "grade",
      title: `${exam.subjectName}: ${score} / ${exam.maxScore}`,
      body: `${known.get(id).name} · ${exam.title}`,
      route: "/grades",
    });
  }
  await log(req.user, {
    kind: "grades",
    action: "exam.scored",
    summary: msg("published {0} scores ({1}) for {2}", exam.title, exam.subjectName, exam.className),
    classId: exam.classId,
    route: "/grades",
  });
  res.json(await scoreSheet(await repo.findExam(req.user.institutionId, exam.id)));
});

// ---------- helpers ----------

async function classOr404(req) {
  const schoolClass = await academics.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

async function examOr404(req) {
  const exam = await repo.findExam(req.user.institutionId, req.params.examId);
  if (!exam) throw new HttpError(404, "Exam not found.");
  return exam;
}

/** The subject is studied in the class, taught by this user, on a school day. */
async function checkExam(req, schoolClass, body) {
  if (!schoolClass.subjects.some((s) => s.subjectId === body.subjectId)) {
    throw new HttpError(400, "{0} doesn't study this subject.", [schoolClass.name]);
  }
  checkTeaches(req.user, schoolClass, body.subjectId);
  const calendar = await schoolCalendar(req.user.institutionId);
  if (!calendar?.isSchoolDay(body.date)) {
    throw new HttpError(400, "Choose a school day of this study year.");
  }
}

async function scoreSheet(exam) {
  const scores = await repo.scoresOf(exam.id);
  const students = await attendance.classStudents(exam.classId);
  return {
    exam,
    students: students.map((s) => ({ ...s, score: scores.get(s.id) ?? null })),
  };
}

module.exports = router;
