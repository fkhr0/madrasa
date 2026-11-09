// Sign in, stay signed in, sign out.
const express = require("express");
const bcrypt = require("bcryptjs");
const { HttpError, validate, z } = require("../../common/http");
const users = require("../users/users.repository");
const { userWithChildren } = require("../users/users.mapper");
const tokens = require("./tokens");
const lockout = require("./lockout");
const demo = require("./demo");
const { signInLimit, resetLimit } = require("../../common/security");
const { log } = require("../activity/log");
const { msg, t } = require("../../i18n");
const config = require("../../config");

const router = express.Router();

const WRONG = "The ID or password is not correct.";

/**
 * Compared against when the ID doesn't exist, so the answer takes as long
 * as for a wrong password (the time must not tell which IDs exist).
 */
const NO_ONE = bcrypt.hashSync("no such account", config.bcryptCost);

// POST /auth/login { schoolId, password } -> { accessToken, refreshToken, user }
router.post("/login", signInLimit, async (req, res) => {
  const { schoolId, password } = validate(
    z.object({
      schoolId: z.string().trim().min(1),
      password: z.string().min(1),
    }),
    req.body,
  );

  const id = schoolId.toUpperCase();
  const waitSeconds = await lockout.lockedFor(id);
  if (waitSeconds > 0) {
    throw new HttpError(429, "Too many wrong passwords. Try again in {0} minutes.", [
      Math.ceil(waitSeconds / 60),
    ]);
  }

  const user = await users.findById(id);
  // Same message for "no such ID" and "wrong password": don't reveal which IDs exist.
  const matches = await bcrypt.compare(password, user?.password_hash ?? NO_ONE);
  require("../../common/metrics").signIns.inc({ result: user && matches ? "ok" : "wrong" });
  if (!user || !matches) {
    if (await lockout.recordFailure(id) && user) {
      // The office sees it in Activity (someone may be guessing).
      await log(
        { id: user.id, institutionId: user.institution_id, role: user.role },
        {
          kind: "security",
          action: "signin.locked",
          summary: msg("was locked out for 15 minutes after {0} wrong passwords", lockout.MAX_FAILURES),
          route: `/people/${user.id}`,
        },
      );
    }
    throw new HttpError(401, WRONG);
  }
  await lockout.clearFailures(id);
  if (!user.is_active) {
    throw new HttpError(403, "This account is not active. Please contact the school office.",
    );
  }

  res.json({
    accessToken: tokens.signAccessToken(user),
    refreshToken: await tokens.createSession(user.id),
    user: await userWithChildren(user),
  });
});

// GET /auth/demo -> { roles }  (404 when the demo is off)
// POST /auth/demo { role } -> { accessToken, refreshToken, user }
// "Try the demo" on the sign-in page: no password, the demo school only.
router.get("/demo", (_req, res) => {
  if (!config.demoMode) throw new HttpError(404, "Not found.");
  res.json({ roles: Object.keys(demo.DEMO_ACCOUNTS) });
});

router.post("/demo", signInLimit, async (req, res) => {
  if (!config.demoMode) throw new HttpError(404, "Not found.");
  const { role } = validate(
    z.object({ role: z.enum(["student", "parent", "teacher", "admin", "driver"]) }),
    req.body,
  );
  const user = await users.findById(demo.DEMO_ACCOUNTS[role]);
  if (!user) throw new HttpError(503, "The demo school is being prepared. Try again in a minute.");
  res.json({
    accessToken: tokens.signAccessToken(user),
    refreshToken: await tokens.createSession(user.id),
    user: await userWithChildren(user),
  });
});

// POST /auth/refresh { refreshToken } -> { accessToken, refreshToken }
router.post("/refresh", async (req, res) => {
  const { refreshToken } = validate(
    z.object({ refreshToken: z.string().min(1) }),
    req.body,
  );

  const rotated = await tokens.rotateSession(refreshToken);
  const user = await users.findById(rotated.userId);
  if (!user || !user.is_active) throw new HttpError(401, "Please sign in again.");

  res.json({
    accessToken: tokens.signAccessToken(user),
    refreshToken: rotated.refreshToken,
  });
});

// POST /auth/logout { refreshToken } -> 204
router.post("/logout", async (req, res) => {
  await tokens.endSession(req.body?.refreshToken);
  res.status(204).end();
});

// POST /auth/password-reset { emailOrPhone } -> 202
// Accounts belong to the school: the office is told and gives a new
// password (People → reset password). Always the same answer, so nobody can
// test which IDs, emails or phones exist.
router.post("/password-reset", resetLimit, async (req, res) => {
  const { emailOrPhone: who } = validate(
    z.object({ emailOrPhone: z.string().trim().min(3).max(120) }),
    req.body,
  );
  const user = await users.findForReset(who);
  if (user?.is_active) {
    const { notify, admins } = require("../notifications/notify");
    await notify(user.institution_id, await admins(user.institution_id), {
      type: "announcement",
      title: msg("{0} forgot their password", user.name),
      body: msg("{0} · give them a new one in People", user.id),
      route: `/people/${user.id}`,
    });
  }
  res.status(202).json({ message: t("If the account exists, your school office was asked to give you a new password.") });
});

module.exports = router;
