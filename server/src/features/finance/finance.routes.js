// School fees.
const express = require("express");
const { HttpError, validate, isoDate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const institution = require("../institution/institution.repository");
const { notify } = require("../notifications/notify");
const { personOr404 } = require("../users/access");
const { today } = require("../attendance/school-days");
const fees = require("./fees");
const repo = require("./finance.repository");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

const admin = requireRole("admin");
const dinars = z.number().int().min(0).max(1_000_000_000);

// ---------- Settings (office) ----------

// GET /finance/settings -> { tuition, busFee, dueDates, classTuition: [{ classId, className, tuition | null }] }
router.get("/settings", admin, async (req, res) => {
  res.json(await repo.settings(req.user.institutionId));
});

// PUT /finance/settings { tuition, busFee, dueDates, classTuition: { classId: amount | null } }
router.put("/settings", admin, async (req, res) => {
  const body = validate(
    z.object({
      tuition: dinars,
      busFee: dinars,
      dueDates: z.array(isoDate).min(1, "add at least one due date").max(6),
      classTuition: z.record(z.string(), dinars.nullable()).default({}),
    }),
    req.body,
  );
  const dueDates = [...new Set(body.dueDates)].sort();
  const year = await institution.findCurrentYear(req.user.institutionId);
  if (year && dueDates.some((d) => d < year.start || d > year.end)) {
    throw new HttpError(400, "Due dates must be inside the study year.");
  }
  const current = await repo.settings(req.user.institutionId);
  const classIds = new Set(current.classTuition.map((c) => c.classId));
  if (Object.keys(body.classTuition).some((id) => !classIds.has(id))) {
    throw new HttpError(400, "classTuition: unknown class");
  }

  await transaction((tx) =>
    repo.saveSettings(tx, req.user.institutionId, { ...body, dueDates }),
  );
  await log(req.user, {
    kind: "finance",
    action: "fees.changed",
    summary: msg("changed the school fees (tuition {0}, bus {1}, {2} installments)", fees.iqd(body.tuition), fees.iqd(body.busFee), dueDates.length),
  });
  res.json(await repo.settings(req.user.institutionId));
});

// ---------- Accounts ----------

// GET /finance/accounts -> [account]  (office)
router.get("/accounts", admin, async (req, res) => {
  res.json(await repo.accounts(req.user.institutionId));
});

// GET /finance/accounts/:studentId -> account  (office, the student, their parents)
router.get("/accounts/:studentId", async (req, res) => {
  res.json(await accountOr404(req));
});

// PUT /finance/accounts/:studentId/discount { percent, reason } -> account  (office)
router.put("/accounts/:studentId/discount", admin, async (req, res) => {
  const account = await accountOr404(req);
  const body = validate(
    z.object({
      percent: z.number().int().min(0).max(100),
      reason: z.string().trim().max(120).default(""),
    }),
    req.body,
  );
  const paid = fees.paidOf(account);
  const newTotal = fees.totalOf({ ...account, discountPercent: body.percent });
  if (newTotal < paid) {
    throw new HttpError(400, "The family already paid {0}, more than the new total.", [fees.iqd(paid)]);
  }
  await repo.setDiscount(account.studentId, body);
  await log(req.user, {
    kind: "finance",
    action: "discount.set",
    summary: msg("set {0}'s discount to {1}%{2}", account.studentName, body.percent, body.reason ? ` (${body.reason})` : ""),
    studentIds: [account.studentId],
    route: `/finance/${account.studentId}`,
  });
  res.json(await accountOr404(req));
});

// POST /finance/accounts/:studentId/payments { amount, method, note } -> payment  (office)
router.post("/accounts/:studentId/payments", admin, async (req, res) => {
  const account = await accountOr404(req);
  const body = validate(
    z.object({
      amount: z.number().int().positive("enter an amount above zero"),
      method: z.enum(["cash", "bankTransfer", "card", "eWallet"]),
      note: z.string().trim().max(200).default(""),
    }),
    req.body,
  );
  const balance = fees.balanceOf(account);
  if (body.amount > balance) {
    throw new HttpError(400, "That is more than the balance ({0}).", [fees.iqd(balance)]);
  }

  const payment = await transaction((tx) =>
    repo.insertPayment(tx, req.user.institutionId, account.studentId, body, req.user.id),
  );
  const left = balance - body.amount;
  await log(req.user, {
    kind: "finance",
    action: "payment.recorded",
    summary: msg("recorded {0} for {1} ({2})", fees.iqd(body.amount), account.studentName, payment.receiptNumber),
    studentIds: [account.studentId],
    route: `/finance/${account.studentId}`,
  });
  await notify(req.user.institutionId, [account.parentId], {
    type: "payment",
    title: msg("Payment received · {0}", fees.iqd(body.amount)),
    body:
      left === 0
        ? msg("{0}'s fees are paid in full. Thank you!", account.studentName)
        : msg("Receipt {0} · balance {1}", payment.receiptNumber, fees.iqd(left)),
    route: "/fees",
  });
  res.status(201).json(payment);
});

// POST /finance/payments/:id/void { reason } -> 204  (office)
// The payment stays in the records but no longer counts.
router.post("/payments/:id/void", admin, async (req, res) => {
  const { reason } = validate(
    z.object({ reason: z.string().trim().min(3, "say why").max(200) }),
    req.body,
  );
  const payment = await repo.findPayment(req.user.institutionId, req.params.id);
  if (!payment) throw new HttpError(404, "Payment not found.");
  if (payment.voidedAt) throw new HttpError(409, "This payment is already voided.");
  await repo.voidPayment(payment.id, reason);
  await log(req.user, {
    kind: "finance",
    action: "payment.voided",
    summary: msg("voided {0} ({1}): {2}", payment.receiptNumber, fees.iqd(payment.amount), reason),
    studentIds: [payment.studentId],
    route: `/finance/${payment.studentId}`,
  });
  res.status(204).end();
});

// POST /finance/accounts/:studentId/remind -> 204  (office)
router.post("/accounts/:studentId/remind", admin, async (req, res) => {
  const account = await accountOr404(req);
  if (!account.parentId) throw new HttpError(400, "This student has no parent account.");
  const overdue = fees.overdueOf(account, today());
  const balance = fees.balanceOf(account);

  await notify(req.user.institutionId, [account.parentId], {
    type: "payment",
    title: overdue > 0
      ? msg("School fees: {0} overdue", fees.iqd(overdue))
      : msg("School fees reminder"),
    body:
      balance <= 0
        ? msg("Thank you, nothing is due.")
        : msg("For {0}. You can pay at the school office or by bank transfer.", account.studentName),
    route: "/fees",
  });
  res.status(204).end();
});

async function accountOr404(req) {
  const student = await personOr404(req.user, req.params.studentId);
  if (student.role !== "student") throw new HttpError(404, "Account not found.");
  const [account] = await repo.accounts(student.institutionId, student.id);
  if (!account) throw new HttpError(404, "Account not found.");
  return account;
}

module.exports = router;
