// Administrator: subjects, classes, the head teacher of each class and who
// teaches each subject there.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const repo = require("./academics.repository");
const timetable = require("../timetable/timetable.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const DAY_NAMES = [
  "", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
];

const router = express.Router();
router.use(requireAuth, requireRole("admin"));

const ICONS = [
  "book", "math", "physics", "chemistry", "biology", "language",
  "english", "islamic", "computer", "history", "geography", "art", "sport",
];
const COLORS = [
  "blue", "teal", "green", "orange", "purple", "pink", "amber", "gray",
];

const subjectFields = z.object({
  name: z.string().trim().min(2).max(60),
  icon: z.enum(ICONS).default("book"),
  color: z.enum(COLORS).default("blue"),
});

const classFields = z.object({
  name: z.string().trim().min(2).max(60),
  homeroomTeacherId: z.string().nullish(),
});

// ---------- Subjects ----------

router.get("/subjects", async (req, res) => {
  res.json(await repo.listSubjects(req.user.institutionId));
});

router.post("/subjects", async (req, res) => {
  const body = validate(subjectFields, req.body);
  const subject = await uniqueName(() => repo.insertSubject(req.user.institutionId, body));
  await log(req.user, { kind: "academics", action: "subject.added", summary: msg("added the subject {0}", subject.name) });
  res.status(201).json(subject);
});

router.patch("/subjects/:id", async (req, res) => {
  const body = validate(subjectFields, req.body);
  const subject = await uniqueName(() =>
    repo.updateSubject(req.user.institutionId, req.params.id, body),
  );
  if (!subject) throw new HttpError(404, "Subject not found.");
  await log(req.user, { kind: "academics", action: "subject.changed", summary: msg("changed the subject {0}", subject.name) });
  res.json(subject);
});

// Removes the subject from every class too (the app asks first).
router.delete("/subjects/:id", async (req, res) => {
  if (!(await repo.deleteSubject(req.user.institutionId, req.params.id))) {
    throw new HttpError(404, "Subject not found.");
  }
  await log(req.user, { kind: "academics", action: "subject.deleted", summary: msg("deleted a subject ({0})", req.params.id) });
  res.status(204).end();
});

// ---------- Classes ----------

router.get("/classes", async (req, res) => {
  res.json(await repo.listClasses(req.user.institutionId));
});

router.get("/classes/:id", async (req, res) => {
  res.json(await findClassOr404(req));
});

// POST { name, homeroomTeacherId?, subjectIds? } -> class
router.post("/classes", async (req, res) => {
  const body = validate(
    classFields.extend({ subjectIds: z.array(z.string()).default([]) }),
    req.body,
  );
  const institutionId = req.user.institutionId;
  await checkTeachers(institutionId, [body.homeroomTeacherId]);
  if (!(await repo.areSubjects(institutionId, body.subjectIds))) {
    throw new HttpError(400, "subjectIds: unknown subject");
  }

  const id = await uniqueName(() =>
    transaction((tx) => repo.insertClass(tx, institutionId, body)),
  );
  await log(req.user, { kind: "academics", action: "class.added", summary: msg("added the class {0}", body.name), classId: id });
  res.status(201).json(await repo.findClass(institutionId, id));
});

// PATCH { name, homeroomTeacherId? } -> class
router.patch("/classes/:id", async (req, res) => {
  const old = await findClassOr404(req);
  const body = validate(classFields, req.body);
  await checkTeachers(req.user.institutionId, [body.homeroomTeacherId]);

  await uniqueName(() =>
    transaction((tx) => repo.updateClass(tx, req.user.institutionId, old, body)),
  );
  await log(req.user, { kind: "academics", action: "class.changed", summary: msg("changed the class {0}", body.name), classId: old.id });
  res.json(await findClassOr404(req));
});

// DELETE -> 204. Refused while students are in the class.
router.delete("/classes/:id", async (req, res) => {
  const schoolClass = await findClassOr404(req);
  if (schoolClass.studentCount > 0) {
    throw new HttpError(409, "{0} has {1} students. Move them to another class first.", [schoolClass.name, schoolClass.studentCount],
    );
  }
  await repo.deleteClass(req.user.institutionId, schoolClass.id);
  await log(req.user, { kind: "academics", action: "class.deleted", summary: msg("deleted the class {0}", schoolClass.name) });
  res.status(204).end();
});

// PUT /classes/:id/subjects/:subjectId { teacherId | null } -> class
// Adds the subject to the class, or changes who teaches it there.
router.put("/classes/:id/subjects/:subjectId", async (req, res) => {
  const schoolClass = await findClassOr404(req);
  const { teacherId } = validate(
    z.object({ teacherId: z.string().nullish() }),
    req.body,
  );
  const institutionId = req.user.institutionId;
  if (!(await repo.areSubjects(institutionId, [req.params.subjectId]))) {
    throw new HttpError(404, "Subject not found.");
  }
  await checkTeachers(institutionId, [teacherId]);

  // The subject's lessons in this class must fit the new teacher's week.
  const slots = await timetable.subjectSlots(schoolClass.id, req.params.subjectId);
  const [clash] = await timetable.teacherClashes(teacherId, schoolClass.id, slots);
  if (clash) {
    throw new HttpError(409, "{0} already teaches {1} in period {2} on {3}, when {4} has this subject. Move one of the lessons first.", [clash.teacherName, clash.className, clash.period, msg(DAY_NAMES[clash.weekday]), schoolClass.name],
    );
  }

  await repo.setClassSubject(schoolClass.id, req.params.subjectId, teacherId);
  const updated = await findClassOr404(req);
  const taught = updated.subjects.find((s) => s.subjectId === req.params.subjectId);
  await log(req.user, {
    kind: "academics",
    action: "class.subjectTeacher",
    summary: msg("set {0} in {1} to {2}", taught?.subjectName ?? "a subject", updated.name, taught?.teacherName ?? "no teacher"),
    classId: updated.id,
  });
  res.json(updated);
});

// DELETE /classes/:id/subjects/:subjectId -> class
router.delete("/classes/:id/subjects/:subjectId", async (req, res) => {
  const schoolClass = await findClassOr404(req);
  if (!(await repo.removeClassSubject(schoolClass.id, req.params.subjectId))) {
    throw new HttpError(404, "The class doesn't have this subject.");
  }
  await log(req.user, {
    kind: "academics",
    action: "class.subjectRemoved",
    summary: msg("removed a subject ({0}) from {1}", req.params.subjectId, schoolClass.name),
    classId: schoolClass.id,
  });
  res.json(await findClassOr404(req));
});

// ---------- helpers ----------

async function findClassOr404(req) {
  const schoolClass = await repo.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

async function checkTeachers(institutionId, ids) {
  if (!(await repo.areTeachers(institutionId, ids))) {
    throw new HttpError(400, "Choose a teacher of your school.");
  }
}

/** Turns "duplicate name" from the database into a clear message. */
async function uniqueName(work) {
  try {
    return await work();
  } catch (err) {
    if (err.code === "23505") {
      throw new HttpError(409, "That name is already used. Choose another.");
    }
    throw err;
  }
}

module.exports = router;
