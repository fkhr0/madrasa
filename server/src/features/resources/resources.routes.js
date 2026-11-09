// Study material: a teacher (or the office) shares a file or a link with a
// class for a subject; its students (and their parents) see it.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { query, queryOne } = require("../../db/database");
const academics = require("../academics/academics.repository");
const { taughtBy, checkTeaches } = require("../academics/teaches");
const files = require("../files/files.repository");
const { personOr404 } = require("../users/access");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const RESOURCE = `
  SELECT r.id, r.class_id AS "classId", r.title, r.type, r.url, r.created_at AS "uploadedAt",
         s.id AS "subjectId", s.name AS "subjectName", s.icon, s.color,
         f.id AS "fileId", f.name AS "fileName", f.size_bytes AS "fileSize"
  FROM resources r
  JOIN subjects s ON s.id = r.subject_id
  JOIN classes c ON c.id = r.class_id
  LEFT JOIN files f ON f.id = r.file_id`;

// GET /resources/students/:id -> [resource]  (newest first)
router.get("/students/:id", async (req, res) => {
  const student = await personOr404(req.user, req.params.id);
  if (student.role !== "student" || !student.className) return res.json([]);
  res.json(
    await query(
      `${RESOURCE} WHERE c.institution_id = $1 AND c.name = $2 ORDER BY r.created_at DESC`,
      [student.institutionId, student.className],
    ),
  );
});

const staff = requireRole("teacher", "admin");

// GET /resources/teaching -> [resource]  (newest first)
// A teacher: what they share in all their classes. The office: the school's.
router.get("/teaching", staff, async (req, res) => {
  const mine =
    req.user.role === "admin"
      ? ["c.institution_id = $1", req.user.institutionId]
      : [
          `EXISTS (SELECT 1 FROM class_subjects cs WHERE cs.class_id = r.class_id
                     AND cs.subject_id = r.subject_id AND cs.teacher_id = $1)`,
          req.user.id,
        ];
  res.json(await query(`${RESOURCE} WHERE ${mine[0]} ORDER BY r.created_at DESC`, [mine[1]]));
});

// GET /resources/classes/:id -> [resource]  (a teacher: their subjects)
router.get("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const mine = taughtBy(req.user, schoolClass);
  const all = await query(`${RESOURCE} WHERE r.class_id = $1 ORDER BY r.created_at DESC`, [
    schoolClass.id,
  ]);
  res.json(all.filter((r) => mine(r.subjectId)));
});

// POST /resources/classes/:id { subjectId, title, type, fileId | url } -> resource
router.post("/classes/:id", staff, async (req, res) => {
  const schoolClass = await classOr404(req);
  const body = validate(
    z.object({
      subjectId: z.string(),
      title: z.string().trim().min(2).max(120),
      type: z.enum(["pdf", "slides", "video", "link"]),
      fileId: z.string().nullish(),
      url: z.url({ protocol: /^https?$/ }).nullish(),
    }),
    req.body,
  );
  if (!schoolClass.subjects.some((s) => s.subjectId === body.subjectId)) {
    throw new HttpError(400, "{0} doesn't study this subject.", [schoolClass.name]);
  }
  checkTeaches(req.user, schoolClass, body.subjectId);
  if (Boolean(body.fileId) === Boolean(body.url)) {
    throw new HttpError(400, "Add a file or a link.");
  }
  if (body.fileId && (await files.ownFiles(req.user.id, [body.fileId])).length !== 1) {
    throw new HttpError(400, "Upload the file first.");
  }

  const { id } = await queryOne(
    `INSERT INTO resources (institution_id, class_id, subject_id, title, type, file_id, url, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
    [req.user.institutionId, schoolClass.id, body.subjectId, body.title, body.type,
     body.fileId || null, body.url || null, req.user.id],
  );
  await log(req.user, {
    kind: "material",
    action: "material.shared",
    summary: msg("shared \"{0}\" with {1}", body.title, schoolClass.name),
    classId: schoolClass.id,
    route: "/resources",
  });
  res.status(201).json(await queryOne(`${RESOURCE} WHERE r.id = $1`, [id]));
});

// DELETE /resources/:id -> 204  (the app asks first)
router.delete("/:id", staff, async (req, res) => {
  const resource = await queryOne(
    "SELECT id, class_id, subject_id, title FROM resources WHERE id = $1 AND institution_id = $2",
    [req.params.id, req.user.institutionId],
  );
  if (!resource) throw new HttpError(404, "Material not found.");
  const schoolClass = await academics.findClass(req.user.institutionId, resource.class_id);
  checkTeaches(req.user, schoolClass, resource.subject_id);
  await query("DELETE FROM resources WHERE id = $1", [resource.id]);
  await log(req.user, {
    kind: "material",
    action: "material.removed",
    summary: msg("removed \"{0}\" from {1}", resource.title, schoolClass.name),
    classId: schoolClass.id,
  });
  res.status(204).end();
});

async function classOr404(req) {
  const schoolClass = await academics.findClass(req.user.institutionId, req.params.id);
  if (!schoolClass) throw new HttpError(404, "Class not found.");
  return schoolClass;
}

module.exports = router;
