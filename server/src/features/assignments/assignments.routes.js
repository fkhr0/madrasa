// Homework. The subject's teacher (or the office) sets work for a class and
// grades it; students hand it in, with files when the work asks for them;
// parents follow along.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const academics = require("../academics/academics.repository");
const { taughtBy, checkTeaches } = require("../academics/teaches");
const attendance = require("../attendance/attendance.repository");
const files = require("../files/files.repository");
const { notify, withParents } = require("../notifications/notify");
const { personOr404 } = require("../users/access");
const repo = require("./assignments.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const assignmentFields = z.object({
  subjectId: z.string(),
  type: z.enum(["homework", "assignment", "project", "quiz"]),
  title: z.string().trim().min(2).max(120),
  description: z.string().trim().max(4000).default(""),
  dueAt: z.iso.datetime({ offset: true }),
  allowsLate: z.boolean().default(false),
  acceptsFiles: z.boolean().default(true),
  maxGrade: z.number().positive().max(1000).default(10),
  fileIds: z.array(z.string()).max(10).default([]),
});

// ---------- A student's homework ----------

// GET /assignments/students/:id -> [assignment + { submission | null }]
router.get("/students/:id", async (req, res) => {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student" || !student.className) return res.json([]);
  res.json(
    await repo.studentAssignments(student.institutionId, student.className, student.id),
  );
});

// POST /assignments/:id/submission { fileIds } -> assignment + { submission }
// The student hands in (or again, until it is graded).
router.post("/:id/submission", requireRole("student"), async (req, res) => {
  const assignment = await assignmentOr404(req);
  const me = await personOr404(req.user, req.user.id);
  if (assignment.className !== me.className) {
    throw new HttpError(403, "This work is for another class.");
  }
  const { fileIds } = validate(
    z.object({ fileIds: z.array(z.string()).max(10).default([]) }),
    req.body,
  );

  if (assignment.acceptsFiles && fileIds.length === 0) {
    throw new HttpError(400, "Add your work as a file first.");
  }
  if (new Date(assignment.dueAt) < new Date() && !assignment.allowsLate) {
    throw new HttpError(400, "The due date has passed and late work isn't accepted.");
  }
  const old = (await repo.submissionsOf([assignment.id], [me.id])).get(`${assignment.id}/${me.id}`);
  if (old?.grade != null) throw new HttpError(409, "This work is already graded.");
  const mine = await files.ownFiles(me.id, fileIds);
  if (mine.length !== new Set(fileIds).size) {
    throw new HttpError(400, "Upload the files before handing them in.");
  }

  await transaction((tx) => repo.submit(tx, assignment.id, me.id, fileIds));
  await log(req.user, {
    kind: "homework",
    action: "homework.handedIn",
    summary: msg("handed in \"{0}\" ({1})", assignment.title, assignment.subjectName),
    classId: assignment.classId,
    studentIds: [me.id],
    route: `/assignments/${assignment.id}`,
  });
  const [updated] = (
    await repo.studentAssignments(me.institutionId, me.className, me.id)
  ).filter((a) => a.id === assignment.id);
  res.json(updated);
});

// ---------- A class's homework (subject's teacher, or office) ----------

const staff = requireRole("teacher", "admin");

// GET /assignments/classes/:id -> [assignment + { submittedCount, gradedCount }]
router.get("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const mine = taughtBy(req.user, schoolClass);
  res.json((await repo.classAssignments(schoolClass.id)).filter((a) => mine(a.subjectId)));
});

// POST /assignments/classes/:id { ...fields, fileIds } -> assignment
router.post("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const body = await checkedBody(req, schoolClass);

  const id = await transaction((tx) =>
    repo.insertAssignment(tx, req.user.institutionId, schoolClass.id, body, req.user.id),
  );
  const assignment = await repo.findAssignment(req.user.institutionId, id);
  const students = await attendance.classStudents(schoolClass.id);
  await notify(req.user.institutionId, await withParents(students.map((s) => s.id)), {
    type: "assignment",
    title: msg("New {0} {1}", assignment.subjectName, msg(assignment.type)),
    body: assignment.title,
    route: `/assignments/${assignment.id}`,
  });
  await log(req.user, {
    kind: "homework",
    action: "homework.set",
    summary: msg("set \"{0}\" ({1}) for {2}", assignment.title, assignment.subjectName, assignment.className),
    classId: assignment.classId,
    route: `/assignments/${assignment.id}`,
  });
  res.status(201).json(assignment);
});

// PATCH /assignments/:id { ...fields, fileIds } -> assignment
router.patch("/:id", staff, async (req, res) => {
  const assignment = await assignmentOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, assignment.classId);
  checkTeaches(req.user, schoolClass, assignment.subjectId);
  const body = await checkedBody(req, schoolClass, assignment);

  await transaction((tx) => repo.updateAssignment(tx, assignment.id, body));
  const changed = await repo.findAssignment(req.user.institutionId, assignment.id);
  await log(req.user, {
    kind: "homework",
    action: "homework.changed",
    summary: msg("changed \"{0}\" ({1}) for {2}", changed.title, changed.subjectName, changed.className),
    classId: changed.classId,
    route: `/assignments/${changed.id}`,
  });
  res.json(changed);
});

// DELETE /assignments/:id -> 204  (hand-ins and grades go too; the app asks first)
router.delete("/:id", staff, async (req, res) => {
  const assignment = await assignmentOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, assignment.classId);
  checkTeaches(req.user, schoolClass, assignment.subjectId);
  await repo.deleteAssignment(assignment.id);
  await log(req.user, {
    kind: "homework",
    action: "homework.deleted",
    summary: msg("deleted \"{0}\" ({1}) of {2}", assignment.title, assignment.subjectName, assignment.className),
    classId: assignment.classId,
  });
  res.status(204).end();
});

// GET /assignments/:id/submissions
//   -> { assignment, students: [{ id, name, submission | null }] }
router.get("/:id/submissions", staff, async (req, res) => {
  const assignment = await assignmentOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, assignment.classId);
  checkTeaches(req.user, schoolClass, assignment.subjectId);
  res.json(await submissionSheet(assignment));
});

// PUT /assignments/:id/submissions/:studentId/grade { grade, feedback } -> sheet
// Also for work handed in on paper. The student and parents are told.
router.put("/:id/submissions/:studentId/grade", staff, async (req, res) => {
  const assignment = await assignmentOr404(req);
  const schoolClass = await academics.findClass(req.user.institutionId, assignment.classId);
  checkTeaches(req.user, schoolClass, assignment.subjectId);
  const body = validate(
    z.object({
      grade: z.number().min(0).max(assignment.maxGrade, `at most ${assignment.maxGrade}`),
      feedback: z.string().trim().max(2000).default(""),
    }),
    req.body,
  );
  const student = (await attendance.classStudents(assignment.classId)).find(
    (s) => s.id === req.params.studentId,
  );
  if (!student) throw new HttpError(404, "Not a student of {0}.", [assignment.className]);

  await repo.grade(assignment.id, student.id, body);
  await log(req.user, {
    kind: "homework",
    action: "homework.graded",
    summary: msg("graded {0}'s \"{1}\": {2} / {3}", student.name, assignment.title, body.grade, assignment.maxGrade),
    classId: assignment.classId,
    studentIds: [student.id],
    route: `/assignments/${assignment.id}`,
  });
  await notify(req.user.institutionId, await withParents([student.id]), {
    type: "grade",
    title: `${assignment.subjectName}: ${body.grade} / ${assignment.maxGrade}`,
    body: `${student.name} · ${assignment.title}`,
    route: `/assignments/${assignment.id}`,
  });
  res.json(await submissionSheet(assignment));
});

// ---------- helpers ----------

async function classOr404(req) {
  const schoolClass = await academics.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

async function assignmentOr404(req) {
  const assignment = await repo.findAssignment(req.user.institutionId, req.params.id);
  if (!assignment) throw new HttpError(404, "Assignment not found.");
  return assignment;
}

/** The validated body: a subject the class studies and this user teaches, own files. */
async function checkedBody(req, schoolClass, old = null) {
  const body = validate(assignmentFields, req.body);
  if (!schoolClass.subjects.some((s) => s.subjectId === body.subjectId)) {
    throw new HttpError(400, "{0} doesn't study this subject.", [schoolClass.name]);
  }
  checkTeaches(req.user, schoolClass, body.subjectId);

  // New files must be this user's uploads; files already attached may stay.
  const kept = new Set((old?.attachments ?? []).map((f) => f.id));
  const added = body.fileIds.filter((id) => !kept.has(id));
  if ((await files.ownFiles(req.user.id, added)).length !== new Set(added).size) {
    throw new HttpError(400, "Upload the files before attaching them.");
  }
  return body;
}

async function submissionSheet(assignment) {
  const students = await attendance.classStudents(assignment.classId);
  const subs = await repo.submissionsOf([assignment.id], students.map((s) => s.id));
  return {
    assignment,
    students: students.map((s) => ({
      ...s,
      submission: subs.get(`${assignment.id}/${s.id}`) ?? null,
    })),
  };
}

module.exports = router;
