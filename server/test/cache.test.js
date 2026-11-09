const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { query } = require("../src/db/database");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [["admin", "ADM-2020-0001"], ["zainab", "STU-2026-0142"]]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const schoolName = async () => (await request(app).get("/institution").set(as.zainab).expect(200)).body.name;

test("answers come from the cache until anything in the school changes", async () => {
  const name = await schoolName();

  // Changed behind the server's back: the cached answer is still served
  // (proof the database wasn't asked).
  await query("UPDATE institutions SET name = 'Changed directly' WHERE id = 'inst-001'");
  assert.equal(await schoolName(), name);

  // Any change through the app (here: a holiday added) clears the cache.
  const year = (await request(app).get("/academic-year").set(as.admin)).body;
  await request(app)
    .post("/academic-year/holidays")
    .set(as.admin)
    .send({ name: "Sports day", type: "schoolBreak", start: year.end })
    .expect(201);
  assert.equal(await schoolName(), "Changed directly");
});

test("live things are never cached: a new message shows at once", async () => {
  const before = (await request(app).get("/notifications").set(as.zainab)).body.length;
  await query(
    `INSERT INTO notifications (institution_id, user_id, type, title) VALUES ('inst-001', 'STU-2026-0142', 'announcement', 'Hi')`,
  );
  assert.equal((await request(app).get("/notifications").set(as.zainab)).body.length, before + 1);
});
