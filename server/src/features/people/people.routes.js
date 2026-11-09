// Administrator: the school's accounts.
// The server makes the ID (PREFIX-YEAR-NUMBER) and a temporary password; the
// person must choose their own password at first sign-in.
const crypto = require("crypto");
const express = require("express");
const bcrypt = require("bcryptjs");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const { userWithChildren } = require("../users/users.mapper");
const repo = require("./people.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");
const config = require("../../config");
const { notOnDemoAccount } = require("../auth/demo");

const router = express.Router();
router.use(requireAuth, requireRole("admin"));

const ROLES = ["student", "teacher", "parent", "admin", "driver"];
const PREFIX = {
  student: "STU",
  teacher: "TCH",
  parent: "PAR",
  admin: "ADM",
  driver: "DRV",
};

const personFields = z.object({
  name: z
    .string()
    .trim()
    .refine((v) => v.split(/\s+/).length >= 2, "enter the full name"),
  email: z.union([z.literal(""), z.email("not a valid email")]).default(""),
  phone: z
    .string()
    .trim()
    .regex(/^[+0-9 ]{0,20}$/, "only digits, spaces and +")
    .default(""),
  className: z.string().trim().nullish(),
  subjectName: z.string().trim().nullish(),
  childIds: z.array(z.string()).default([]),
});

// GET /people?role=student -> [user]
router.get("/", async (req, res) => {
  const role = z.enum(ROLES).safeParse(req.query.role);
  if (!role.success) throw new HttpError(400, "role: choose a valid role");

  const rows = await repo.listByRole(req.user.institutionId, role.data);
  res.json(await Promise.all(rows.map(userWithChildren)));
});

// GET /people/:id -> user
router.get("/:id", async (req, res) => {
  res.json(await userWithChildren(await findOr404(req)));
});

// POST /people { role, name, email, phone, className?, subjectName?, childIds? }
//   -> { user, temporaryPassword }
router.post("/", async (req, res) => {
  const body = validate(
    personFields.extend({ role: z.enum(ROLES) }),
    req.body,
  );
  await checkRoleFields(req, body.role, body);

  const temporaryPassword = makePassword();
  const passwordHash = await bcrypt.hash(temporaryPassword, config.bcryptCost);
  const institutionId = req.user.institutionId;

  const id = await transaction(async (tx) => {
    const id = await repo.nextId(
      tx,
      PREFIX[body.role],
      new Date().getFullYear(),
    );
    await repo.insertUser(tx, {
      ...body,
      id,
      institutionId,
      passwordHash,
    });
    if (body.role === "parent") await repo.setChildren(tx, id, body.childIds);
    return id;
  });

  const user = await repo.findInInstitution(institutionId, id);
  await log(req.user, {
    kind: "people",
    action: "account.added",
    summary: msg("added the {0} account {1} ({2})", msg(body.role), body.name, id),
    route: `/people/${id}`,
  });
  res.status(201).json({
    user: await userWithChildren(user),
    temporaryPassword,
  });
});

// PATCH /people/:id { name, email, phone, className?, subjectName?, childIds? }
// The role and ID never change; create a new account for another role.
router.patch("/:id", async (req, res) => {
  const person = await findOr404(req);
  const body = validate(personFields, req.body);
  await checkRoleFields(req, person.role, body);

  await transaction(async (tx) => {
    await repo.updateUser(tx, req.user.institutionId, person.id, body);
    if (person.role === "parent") {
      await repo.setChildren(tx, person.id, body.childIds);
    }
  });

  await log(req.user, {
    kind: "people",
    action: "account.changed",
    summary: msg("updated {0}'s account ({1})", body.name, person.id),
    route: `/people/${person.id}`,
  });
  res.json(await userWithChildren(await findOr404(req)));
});

// POST /people/:id/active { isActive } -> user
// A deactivated account can't sign in, and is signed out everywhere.
router.post("/:id/active", async (req, res) => {
  // The accounts "Try the demo" opens stay usable for the next visitor.
  notOnDemoAccount(req.params.id);
  const person = await findOr404(req);
  const { isActive } = validate(z.object({ isActive: z.boolean() }), req.body);
  if (person.id === req.user.id && !isActive) {
    throw new HttpError(400, "You can't deactivate your own account.");
  }

  await repo.setActive(req.user.institutionId, person.id, isActive);
  if (!isActive) await repo.endSessions(person.id);
  await log(req.user, {
    kind: "people",
    action: isActive ? "account.activated" : "account.deactivated",
    summary: msg(
      isActive ? "activated {0}'s account ({1})" : "deactivated {0}'s account ({1})",
      person.name,
      person.id,
    ),
    route: `/people/${person.id}`,
  });
  res.json(await userWithChildren(await findOr404(req)));
});

// POST /people/:id/reset-password -> { user, temporaryPassword }
router.post("/:id/reset-password", async (req, res) => {
  // The accounts "Try the demo" opens stay usable for the next visitor.
  notOnDemoAccount(req.params.id);
  const person = await findOr404(req);
  const temporaryPassword = makePassword();

  await repo.setTemporaryPassword(
    req.user.institutionId,
    person.id,
    await bcrypt.hash(temporaryPassword, config.bcryptCost),
  );
  await repo.endSessions(person.id);
  await log(req.user, {
    kind: "people",
    action: "account.passwordReset",
    summary: msg("reset {0}'s password ({1})", person.name, person.id),
    route: `/people/${person.id}`,
  });

  res.json({
    user: await userWithChildren(await findOr404(req)),
    temporaryPassword,
  });
});

// DELETE /people/:id -> 204
// For mistakes (a wrong or duplicate account). People who leave the school
// should be deactivated instead, so their history stays.
router.delete("/:id", async (req, res) => {
  // The accounts "Try the demo" opens stay usable for the next visitor.
  notOnDemoAccount(req.params.id);
  const person = await findOr404(req);
  if (person.id === req.user.id) {
    throw new HttpError(400, "You can't delete your own account.");
  }

  await repo.deleteUser(req.user.institutionId, person.id);
  await log(req.user, {
    kind: "people",
    action: "account.deleted",
    summary: msg("deleted the account {0} ({1})", person.name, person.id),
  });
  res.status(204).end();
});

// ---------- helpers ----------

async function findOr404(req) {
  const person = await repo.findInInstitution(
    req.user.institutionId,
    req.params.id.toUpperCase(),
  );
  if (!person) throw new HttpError(404, "This person is not in your school.");
  return person;
}

/** Students need a class, teachers a subject, parents at least one child. */
async function checkRoleFields(req, role, body) {
  if (role === "student" && !body.className) {
    throw new HttpError(400, "className: choose a class");
  }
  if (role === "teacher" && !body.subjectName) {
    throw new HttpError(400, "subjectName: choose a subject");
  }
  if (role === "driver" && !body.phone) {
    throw new HttpError(400, "phone: drivers need a phone number");
  }
  if (role === "parent") {
    if (body.childIds.length === 0) {
      throw new HttpError(400, "childIds: link at least one child");
    }
    const found = await repo.countStudents(
      req.user.institutionId,
      body.childIds,
    );
    if (found !== new Set(body.childIds).size) {
      throw new HttpError(400, "childIds: children must be students of your school");
    }
  }
}

/** 8 characters, without ones that look alike (0/O, 1/l/I). */
function makePassword() {
  const chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789";
  return Array.from(
    { length: 8 },
    () => chars[crypto.randomInt(chars.length)],
  ).join("");
}

module.exports = router;
