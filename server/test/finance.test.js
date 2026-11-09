const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const fees = require("../src/features/finance/fees");
const { render } = require("../src/i18n");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [
    ["admin", "ADM-2020-0001"],
    ["zainab", "STU-2026-0142"],
    ["parent", "PAR-2026-0142"],
    ["otherParent", "PAR-2026-0150"],
    ["ahmed", "TCH-2019-0031"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

test("fees are worked out like the app does", () => {
  const account = {
    tuition: 2250000, busFee: 600000, discountPercent: 10,
    dueDates: ["2026-10-01", "2027-01-01", "2027-04-01"],
    payments: [{ amount: 880000 }],
  };
  assert.equal(fees.totalOf(account), 2625000);
  assert.deepEqual(fees.installmentsOf(account).map((i) => i.amount), [875000, 875000, 875000]);
  assert.equal(fees.overdueOf(account, "2026-11-08"), 0);
  assert.equal(fees.overdueOf(account, "2027-01-02"), 870000);
  assert.equal(render(fees.iqd(1250000), "en"), "1,250,000 IQD");
  assert.equal(render(fees.iqd(1250000), "ar"), "1,250,000 د.ع");
});

test("Zainab's account: class tuition, sibling discount, first installment paid", async () => {
  const account = (await request(app).get("/finance/accounts/STU-2026-0142").set(as.parent).expect(200)).body;
  assert.equal(account.tuition, 2250000);
  assert.equal(account.discountPercent, 10);
  assert.equal(account.parentId, "PAR-2026-0142");
  assert.deepEqual(account.dueDates, ["2026-10-01", "2027-01-01", "2027-04-01"]);
  assert.equal(account.payments.length, 1);
  assert.equal(account.payments[0].amount, fees.installmentsOf(account)[0].amount);

  await request(app).get("/finance/accounts/STU-2026-0142").set(as.zainab).expect(200);
  await request(app).get("/finance/accounts/STU-2026-0142").set(as.otherParent).expect(404);
  await request(app).get("/finance/accounts").set(as.parent).expect(403);

  const all = (await request(app).get("/finance/accounts").set(as.admin).expect(200)).body;
  assert.ok(all.length > 5);
});

test("the office records a payment with the next receipt number, then voids it", async () => {
  const before = (await request(app).get("/finance/accounts/STU-2026-0142").set(as.admin)).body;
  const balance = fees.balanceOf(before);

  await request(app)
    .post("/finance/accounts/STU-2026-0142/payments")
    .set(as.admin)
    .send({ amount: balance + 1, method: "cash" })
    .expect(400);
  await request(app)
    .post("/finance/accounts/STU-2026-0142/payments")
    .set(as.ahmed)
    .send({ amount: 1000, method: "cash" })
    .expect(403);

  const payment = (
    await request(app)
      .post("/finance/accounts/STU-2026-0142/payments")
      .set(as.admin)
      .send({ amount: 250000, method: "eWallet", note: "Zain Cash" })
      .expect(201)
  ).body;
  assert.match(payment.receiptNumber, /^RCP-\d{4}-\d{4}$/);

  const told = (await request(app).get("/notifications").set(as.parent)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(items.some((n) => n.title === "Payment received · 250,000 IQD"));

  await request(app).post(`/finance/payments/${payment.id}/void`).set(as.admin).send({ reason: "" }).expect(400);
  await request(app).post(`/finance/payments/${payment.id}/void`).set(as.admin).send({ reason: "Typed twice" }).expect(204);
  await request(app).post(`/finance/payments/${payment.id}/void`).set(as.admin).send({ reason: "Again" }).expect(409);

  const after = (await request(app).get("/finance/accounts/STU-2026-0142").set(as.admin)).body;
  assert.equal(fees.balanceOf(after), balance);
});

test("settings, discounts and reminders", async () => {
  const settings = (await request(app).get("/finance/settings").set(as.admin).expect(200)).body;
  assert.equal(settings.busFee, 600000);
  assert.equal(settings.classTuition.find((c) => c.classId === "cls-6c").tuition, 2500000);

  await request(app)
    .put("/finance/settings")
    .set(as.admin)
    .send({ ...settings, dueDates: ["2030-01-01"], classTuition: {} })
    .expect(400);
  const saved = (
    await request(app)
      .put("/finance/settings")
      .set(as.admin)
      .send({ tuition: 2100000, busFee: 650000, dueDates: ["2027-01-01", "2026-10-01"], classTuition: { "cls-6c": null } })
      .expect(200)
  ).body;
  assert.deepEqual(saved.dueDates, ["2026-10-01", "2027-01-01"]);
  assert.equal(saved.classTuition.find((c) => c.classId === "cls-6c").tuition, null);

  const discounted = (
    await request(app)
      .put("/finance/accounts/STU-2026-0142/discount")
      .set(as.admin)
      .send({ percent: 20, reason: "Teacher's child" })
      .expect(200)
  ).body;
  assert.equal(discounted.discountPercent, 20);

  await request(app).post("/finance/accounts/STU-2026-0142/remind").set(as.admin).expect(204);
  const told = (await request(app).get("/notifications").set(as.parent)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(items.some((n) => n.type === "payment" && /School fees/.test(n.title)));
});
