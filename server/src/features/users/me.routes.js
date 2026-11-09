// The signed-in user's own account.
// Name, class and ID are managed by the school; users change contact info
// and their password only.
const express = require("express");
const bcrypt = require("bcryptjs");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const users = require("./users.repository");
const { userWithChildren } = require("./users.mapper");
const tokens = require("../auth/tokens");
const config = require("../../config");
const { notOnDemoAccount } = require("../auth/demo");
const { notify, admins } = require("../notifications/notify");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

// GET /me -> user
router.get("/", async (req, res) => {
  const user = await users.findById(req.user.id);
  if (!user) throw new HttpError(404, "Account not found.");
  res.json(await userWithChildren(user));
});

// PATCH /me { email, phone } -> user
router.patch("/", async (req, res) => {
  const body = validate(
    z.object({
      email: z.union([z.literal(""), z.email("not a valid email")]),
      phone: z
        .string()
        .trim()
        .regex(/^[+0-9 ]{0,20}$/, "only digits, spaces and +"),
    }),
    req.body,
  );

  await users.updateContact(req.user.id, body);
  res.json(await userWithChildren(await users.findById(req.user.id)));
});

// POST /me/sign-out-everywhere { refreshToken } -> 204
// Every other phone and computer is signed out; this one stays in.
router.post("/sign-out-everywhere", async (req, res) => {
  notOnDemoAccount(req.user.id);
  const { refreshToken } = validate(z.object({ refreshToken: z.string().optional() }), req.body);
  await tokens.endAllSessions(req.user.id, refreshToken);
  res.status(204).end();
});

// POST /me/deletion-request { reason? } -> 204
// Accounts belong to the school: the office is told and deletes it (People).
router.post("/deletion-request", async (req, res) => {
  notOnDemoAccount(req.user.id);
  const { reason } = validate(
    z.object({ reason: z.string().trim().max(500).optional() }),
    req.body,
  );
  const user = await users.findById(req.user.id);
  await notify(req.user.institutionId, await admins(req.user.institutionId), {
    type: "announcement",
    title: msg("{0} asked for their account to be deleted", user.name),
    body: reason
      ? msg("{0} · {1} · within 30 days, in People", user.id, reason)
      : msg("{0} · within 30 days, in People", user.id),
    route: `/people/${user.id}`,
  });
  await log(req.user, {
    kind: "security",
    action: "account.deletion-requested",
    summary: msg("asked for their account to be deleted"),
    route: `/people/${user.id}`,
  });
  res.status(204).end();
});

// POST /me/password { currentPassword, newPassword, refreshToken? } -> 204
// Signs the user out everywhere else (the device sending refreshToken stays in).
router.post("/password", async (req, res) => {
  notOnDemoAccount(req.user.id);
  const { currentPassword, newPassword, refreshToken } = validate(
    z.object({
      currentPassword: z.string().min(1),
      newPassword: z.string().min(8, "at least 8 characters"),
      refreshToken: z.string().optional(),
    }),
    req.body,
  );

  const user = await users.findById(req.user.id);
  if (!(await bcrypt.compare(currentPassword, user.password_hash))) {
    throw new HttpError(400, "Your current password is not correct.");
  }

  await users.updatePasswordHash(user.id, await bcrypt.hash(newPassword, config.bcryptCost));
  await tokens.endAllSessions(user.id, refreshToken);
  res.status(204).end();
});

module.exports = router;
