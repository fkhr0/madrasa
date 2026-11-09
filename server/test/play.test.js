const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [["admin", "ADM-2020-0001"], ["zainab", "STU-2026-0142"]]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

test("the privacy and account deletion pages are public, in both languages", async () => {
  for (const page of ["/privacy", "/delete-account"]) {
    const res = await request(app).get(page).expect(200);
    assert.match(res.headers["content-type"], /html/);
    assert.match(res.text, /lang="ar"/);
    assert.match(res.text, /lang="en"/);
    assert.doesNotMatch(res.text, /\{\{/); // every placeholder filled
  }
});

test("asking for account deletion tells the office", async () => {
  await request(app).post("/me/deletion-request").set(as.zainab).send({ reason: "Moving school" }).expect(204);
  const told = (await request(app).get("/notifications").set(as.admin)).body;
  assert.ok(told.some((n) => n.title === "Zainab Haider asked for their account to be deleted"));
});

test("signing out everywhere keeps only this device", async () => {
  const phone = await signIn(app, "STU-2026-0150");
  const laptop = await signIn(app, "STU-2026-0150");
  await request(app)
    .post("/me/sign-out-everywhere")
    .set({ Authorization: `Bearer ${phone.accessToken}` })
    .send({ refreshToken: phone.refreshToken })
    .expect(204);
  await request(app).post("/auth/refresh").send({ refreshToken: laptop.refreshToken }).expect(401);
  await request(app).post("/auth/refresh").send({ refreshToken: phone.refreshToken }).expect(200);
});
