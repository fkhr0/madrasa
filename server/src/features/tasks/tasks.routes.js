// Each person's own tasks and reminders. Nobody else can see them.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const { query, queryOne } = require("../../db/database");

const router = express.Router();
router.use(requireAuth);

const TASK = `id, title, note, due_at AS "dueAt", priority, repeat,
  is_done AS "isDone", is_reminder AS "isReminder", route`;

// GET /tasks -> [task]  (earliest due first)
router.get("/", async (req, res) => {
  res.json(
    await query(`SELECT ${TASK} FROM tasks WHERE user_id = $1 ORDER BY due_at`, [req.user.id]),
  );
});

// POST /tasks { id, title, note?, dueAt, priority, repeat, isReminder, route? } -> task
router.post("/", async (req, res) => {
  const t = validate(
    z.object({
      id: z.string().min(1).max(64),
      title: z.string().trim().min(1).max(200),
      note: z.string().trim().max(1000).nullish(),
      dueAt: z.iso.datetime({ offset: true }),
      priority: z.enum(["low", "medium", "high"]).default("medium"),
      repeat: z.enum(["none", "daily", "weekly", "monthly"]).default("none"),
      isDone: z.boolean().default(false),
      isReminder: z.boolean().default(false),
      route: z.string().max(200).nullish(),
    }),
    req.body,
  );
  const saved = await queryOne(
    `INSERT INTO tasks (user_id, id, title, note, due_at, priority, repeat, is_done, is_reminder, route)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (user_id, id) DO NOTHING
     RETURNING ${TASK}`,
    [req.user.id, t.id, t.title, t.note || null, t.dueAt, t.priority, t.repeat, t.isDone, t.isReminder, t.route || null],
  );
  if (!saved) throw new HttpError(409, "That task already exists.");
  res.status(201).json(saved);
});

// PATCH /tasks/:id { isDone } -> task
router.patch("/:id", async (req, res) => {
  const { isDone } = validate(z.object({ isDone: z.boolean() }), req.body);
  const task = await queryOne(
    `UPDATE tasks SET is_done = $3 WHERE user_id = $1 AND id = $2 RETURNING ${TASK}`,
    [req.user.id, req.params.id, isDone],
  );
  if (!task) throw new HttpError(404, "Task not found.");
  res.json(task);
});

// DELETE /tasks/:id -> 204
router.delete("/:id", async (req, res) => {
  const rows = await query(
    "DELETE FROM tasks WHERE user_id = $1 AND id = $2 RETURNING id",
    [req.user.id, req.params.id],
  );
  if (rows.length === 0) throw new HttpError(404, "Task not found.");
  res.status(204).end();
});

module.exports = router;
