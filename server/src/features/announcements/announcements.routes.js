// Announcements. Everyone reads what is meant for them.
// Administrators announce to anyone and pin; teachers announce to their own
// classes. The author or an administrator edits and deletes.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const users = require("../users/users.repository");
const repo = require("./announcements.repository");
const { sendDueAnnouncements } = require("./announce");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const fields = z
  .object({
    title: z.string().trim().min(2).max(150),
    body: z.string().trim().min(1).max(5000),
    audience: z.enum(["school", "class", "parents", "teachers"]),
    className: z.string().trim().nullish(),
    // Only when publishing: a future time schedules it.
    publishedAt: z.string().datetime({ offset: true }).nullish(),
    isPinned: z.boolean().default(false),
  })
  .refine((a) => a.audience !== "class" || a.className, {
    message: "Choose a class",
  });

/**
 * Checks what this user may send and turns the class name into its ID.
 * Teachers: only to classes they teach, and they cannot pin.
 */
async function resolve(user, body, wasPinned = false) {
  let classId = null;
  if (body.audience === "class") {
    const found = await repo.findClassByName(user.institutionId, body.className);
    if (!found) throw new HttpError(400, "That class does not exist.");
    classId = found.id;
  }

  if (user.role === "teacher") {
    if (body.audience !== "class") {
      throw new HttpError(403, "Teachers announce to their own classes.");
    }
    if (!(await repo.teachesClass(user.id, classId))) {
      throw new HttpError(403, "You don't teach that class.");
    }
    return { ...body, classId, isPinned: wasPinned };
  }

  return { ...body, classId };
}

/** The announcement, if this user may change it (author or admin). */
async function findEditable(user, id) {
  const found = await repo.find(user.institutionId, id);
  if (!found) throw new HttpError(404, "Announcement not found.");
  if (user.role !== "admin" && found.authorId !== user.id) {
    throw new HttpError(403, "Only its author or an administrator can change it.");
  }
  return found;
}

// GET /announcements -> [announcement]
router.get("/", async (req, res) => {
  res.json(await repo.listFor(req.user));
});

// POST /announcements -> announcement  (teachers and admins)
router.post("/", requireRole("teacher", "admin"), async (req, res) => {
  const body = await resolve(req.user, validate(fields, req.body));
  const author = await users.findById(req.user.id);
  const created = await repo.insert(req.user.institutionId, author, body);
  // Published now: tell everyone it is for (scheduled ones wait their time).
  await sendDueAnnouncements();
  await log(req.user, {
    kind: "announcement",
    action: "announcement.posted",
    summary: msg("posted \"{0}\"", created.title),
    classId: created.classId ?? null,
    route: `/announcements/${created.id}`,
  });
  res.status(201).json(created);
});

// PATCH /announcements/:id -> announcement  (author or admin)
router.patch("/:id", async (req, res) => {
  const old = await findEditable(req.user, req.params.id);
  const body = await resolve(req.user, validate(fields, req.body), old.isPinned);
  res.json(await repo.update(req.user.institutionId, old.id, body));
});

// DELETE /announcements/:id -> 204  (author or admin)
router.delete("/:id", async (req, res) => {
  const old = await findEditable(req.user, req.params.id);
  await repo.remove(req.user.institutionId, old.id);
  await log(req.user, {
    kind: "announcement",
    action: "announcement.deleted",
    summary: msg("deleted the announcement \"{0}\"", old.title),
  });
  res.status(204).end();
});

module.exports = router;
