// School events and meetings on the calendar.
// Everyone reads what is meant for them; administrators add, edit and delete.
const express = require("express");
const { HttpError, validate, isoDate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const repo = require("./events.repository");
const { notify, audience } = require("../notifications/notify");
const { msg } = require("../../i18n");

/** Who is told about a new event of each audience. */
const TOLD = {
  everyone: ["student", "parent", "teacher"],
  families: ["parent", "teacher"],
  staff: ["teacher", "admin"],
};

const router = express.Router();
router.use(requireAuth);

/** Which audiences each role sees. */
const AUDIENCES = {
  student: ["everyone"],
  driver: ["everyone"],
  parent: ["everyone", "families"],
  teacher: ["everyone", "families", "staff"],
  admin: ["everyone", "families", "staff"],
};

const eventFields = z
  .object({
    title: z.string().trim().min(2).max(120),
    type: z.enum(["event", "meeting"]),
    audience: z.enum(["everyone", "families", "staff"]),
    date: isoDate,
    time: z
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d$/, "use HH:MM")
      .nullish(),
    endDate: isoDate.nullish(),
    place: z.string().trim().max(120).default(""),
    details: z.string().trim().max(1000).default(""),
  })
  .refine((e) => !e.endDate || e.endDate >= e.date, {
    message: "endDate must be on or after date",
  });

// GET /events -> [event]
router.get("/", async (req, res) => {
  res.json(
    await repo.list(req.user.institutionId, AUDIENCES[req.user.role] ?? []),
  );
});

// POST /events -> event  (admin)
router.post("/", requireRole("admin"), async (req, res) => {
  const body = validate(eventFields, req.body);
  const event = await repo.insert(req.user.institutionId, req.user.id, body);
  const people = await audience(req.user.institutionId, {
    roles: TOLD[event.audience],
    exceptId: req.user.id,
  });
  await notify(req.user.institutionId, people, {
    type: "schedule",
    title: msg("New {0}: {1}", event.type === "meeting" ? "meeting" : "event", event.title),
    body: [event.date, event.time, event.place].filter(Boolean).join(" · "),
    route: "/calendar",
  });
  res.status(201).json(event);
});

// PATCH /events/:id -> event  (admin)
router.patch("/:id", requireRole("admin"), async (req, res) => {
  const body = validate(eventFields, req.body);
  const event = await repo.update(req.user.institutionId, req.params.id, body);
  if (!event) throw new HttpError(404, "Event not found.");
  res.json(event);
});

// DELETE /events/:id -> 204  (admin)
router.delete("/:id", requireRole("admin"), async (req, res) => {
  if (!(await repo.remove(req.user.institutionId, req.params.id))) {
    throw new HttpError(404, "Event not found.");
  }
  res.status(204).end();
});

module.exports = router;
