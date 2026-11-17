const express = require("express");
const { validate, isoDate, z } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const { query } = require("../../db/database");
const config = require("../../config");
const { KINDS } = require("./log");

const router = express.Router();
router.use(requireAuth);

const CLASS_NEWS = ["homework", "grades", "material"];

const filters = z.object({
  date: isoDate.optional(),
  from: isoDate.optional(),
  to: isoDate.optional(),
  kind: z
    .string()
    .optional()
    .transform((k) => (k ? k.split(",").filter((x) => KINDS.includes(x)) : [])),
  actorId: z.string().optional(),
  classId: z.string().optional(),
  studentId: z.string().optional(),
  q: z.string().trim().max(80).optional(),
  before: z.iso.datetime({ offset: true }).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

router.get("/", async (req, res) => {
  const f = validate(filters, req.query);
  const where = [];
  const params = [];
  const add = (sql, ...values) => {
    let text = sql;
    for (const v of values) {
      params.push(v);
      text = text.replace("?", `$${params.length}`);
    }
    where.push(text);
  };

  const me = req.user;
  if (me.role === "admin") {
    add("a.institution_id = ?", me.institutionId);
  } else if (me.role === "teacher") {
    add(
      `a.institution_id = ? AND (a.actor_id = ? OR a.class_id IN (
         SELECT class_id FROM class_subjects WHERE teacher_id = ?
         UNION SELECT id FROM classes WHERE homeroom_teacher_id = ?))`,
      me.institutionId, me.id, me.id, me.id,
    );
  } else {
    const ids =
      me.role === "parent"
        ? (await query("SELECT child_id FROM parent_children WHERE parent_id = $1", [me.id])).map(
            (r) => r.child_id,
          )
        : [me.id];
    add(
      `(a.student_ids && ?::text[] OR (cardinality(a.student_ids) = 0 AND a.kind = ANY(?) AND
         a.class_id IN (SELECT c.id FROM classes c JOIN users u
           ON u.institution_id = c.institution_id AND u.class_name = c.name WHERE u.id = ANY(?))))`,
      ids, CLASS_NEWS, ids,
    );
  }

  if (f.date) add("(a.at AT TIME ZONE ?)::date = ?", config.timeZone, f.date);
  if (f.from) add("(a.at AT TIME ZONE ?)::date >= ?", config.timeZone, f.from);
  if (f.to) add("(a.at AT TIME ZONE ?)::date <= ?", config.timeZone, f.to);
  if (f.kind.length > 0) add("a.kind = ANY(?)", f.kind);
  if (f.actorId) add("a.actor_id = ?", f.actorId);
  if (f.classId) add("a.class_id = ?", f.classId);
  if (f.studentId) add("? = ANY(a.student_ids)", f.studentId);
  if (f.q) {
    const like = `%${f.q.replace(/[%_\\]/g, "\\$&")}%`;
    add("(a.summary ILIKE ? OR a.summary_ar ILIKE ?)", like, like);
  }
  if (f.before) add("a.at < ?", f.before);

  params.push(f.limit + 1);
  params.push(req.language);
  const languageSlot = `$${params.length}`;
  const rows = await query(
    `SELECT a.id, a.at, a.actor_id AS "actorId", a.actor_name AS "actorName",
            a.actor_role AS "actorRole", a.kind, a.action,
            COALESCE(CASE WHEN ${languageSlot} = 'ar' THEN a.summary_ar END, a.summary) AS summary,
            a.class_id AS "classId", c.name AS "className", a.route
     FROM activity_log a LEFT JOIN classes c ON c.id = a.class_id
     WHERE ${where.join(" AND ")}
     ORDER BY a.at DESC, a.id DESC
     LIMIT $${params.length - 1}`,
    params,
  );

  const more = rows.length > f.limit;
  const items = rows.slice(0, f.limit);
  res.json({ items, next: more ? new Date(items.at(-1).at).toISOString() : null });
});

module.exports = router;
