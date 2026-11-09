const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [role, id] of [
    ["admin", "ADM-2020-0001"],
    ["student", "STU-2026-0142"],
    ["parent", "PAR-2026-0142"],
    ["teacher", "TCH-2019-0031"],
  ]) {
    as[role] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const titles = async (who) =>
  (await request(app).get("/events").set(who).expect(200)).body.map((e) => e.title);

test("each role sees the events meant for them", async () => {
  const student = await titles(as.student);
  const parent = await titles(as.parent);
  const teacher = await titles(as.teacher);

  assert.ok(student.includes("Science fair"));
  assert.ok(!student.includes("Parent–teacher meeting"));
  assert.ok(parent.includes("Parent–teacher meeting"));
  assert.ok(!parent.includes("Mathematics department meeting"));
  assert.ok(teacher.includes("Mathematics department meeting"));
});

test("an administrator adds, edits and deletes an event", async () => {
  const created = await request(app)
    .post("/events")
    .set(as.admin)
    .send({
      title: "Reading week",
      type: "event",
      audience: "everyone",
      date: "2026-12-06",
      endDate: "2026-12-10",
      time: null,
      place: "Library",
    })
    .expect(201);
  assert.equal(created.body.endDate, "2026-12-10");
  assert.equal(created.body.time, null);

  const edited = await request(app)
    .patch(`/events/${created.body.id}`)
    .set(as.admin)
    .send({ ...created.body, title: "Reading week 📚", time: "08:00" })
    .expect(200);
  assert.equal(edited.body.time, "08:00");

  await request(app).delete(`/events/${created.body.id}`).set(as.admin).expect(204);
  assert.ok(!(await titles(as.student)).includes("Reading week 📚"));
});

test("others can't change events; bad times are refused", async () => {
  await request(app)
    .post("/events")
    .set(as.teacher)
    .send({ title: "Party", type: "event", audience: "everyone", date: "2026-12-01" })
    .expect(403);
  await request(app)
    .post("/events")
    .set(as.admin)
    .send({ title: "Late", type: "event", audience: "everyone", date: "2026-12-01", time: "25:00" })
    .expect(400);
});

test("an administrator edits a holiday", async () => {
  const year = (await request(app).get("/academic-year").set(as.admin)).body;
  const eid = year.holidays.find((h) => h.name === "Eid al-Fitr");

  const res = await request(app)
    .patch(`/academic-year/holidays/${eid.id}`)
    .set(as.admin)
    .send({ ...eid, start: "2027-03-10", end: "2027-03-13" })
    .expect(200);
  assert.equal(res.body.start, "2027-03-10");
});
