const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
let admin;
let student;
before(async () => {
  app = await startTestApp();
  admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };
  student = { Authorization: `Bearer ${(await signIn(app, "STU-2026-0142")).accessToken}` };
});
after(close);

test("everyone reads their school's study year, dates as plain days", async () => {
  const res = await request(app).get("/academic-year").set(student).expect(200);

  assert.equal(res.body.name, "2026–2027");
  assert.equal(res.body.start, "2026-09-20");
  assert.deepEqual(res.body.workingDays, [7, 1, 2, 3, 4]);
  assert.equal(res.body.terms.length, 2);
  assert.ok(res.body.holidays.some((h) => h.name === "Eid al-Fitr" && h.end === "2027-03-12"));
});

test("only administrators change things", async () => {
  await request(app)
    .post("/academic-year/holidays")
    .set(student)
    .send({ name: "Day off", type: "schoolBreak", start: "2026-11-10" })
    .expect(403);

  await request(app)
    .patch("/institution")
    .set(student)
    .send({ name: "Hacked", type: "school", city: "" })
    .expect(403);
});

test("an administrator adds and removes a holiday", async () => {
  const added = await request(app)
    .post("/academic-year/holidays")
    .set(admin)
    .send({ name: "Exam preparation", type: "schoolBreak", start: "2026-12-20", end: "2026-12-21" })
    .expect(201);
  assert.ok(added.body.id);

  // Outside the study year: refused.
  await request(app)
    .post("/academic-year/holidays")
    .set(admin)
    .send({ name: "Summer", type: "schoolBreak", start: "2027-07-01" })
    .expect(400);

  await request(app)
    .delete(`/academic-year/holidays/${added.body.id}`)
    .set(admin)
    .expect(204);
  await request(app)
    .delete(`/academic-year/holidays/${added.body.id}`)
    .set(admin)
    .expect(404);
});

test("an administrator edits the school's settings", async () => {
  const res = await request(app)
    .patch("/institution")
    .set(admin)
    .send({
      name: "Al-Noor Model School",
      city: "Baghdad",
      address: "14th of Ramadan street",
      phone: "+964 790 000 1111",
      latitude: 33.31,
      longitude: 44.36,
    })
    .expect(200);
  assert.equal(res.body.name, "Al-Noor Model School");
  assert.equal(res.body.latitude, 33.31);

  // Half a location is refused.
  await request(app)
    .patch("/institution")
    .set(admin)
    .send({ name: "Al-Noor Model School", latitude: 33.31 })
    .expect(400);

  await request(app)
    .patch("/academic-year")
    .set(admin)
    .send({ workingDays: [7, 1, 2, 3, 4, 6] })
    .expect(204);
  const year = await request(app).get("/academic-year").set(student);
  assert.deepEqual(year.body.workingDays, [1, 2, 3, 4, 6, 7]);
  await request(app).patch("/academic-year").set(student).send({ workingDays: [1] }).expect(403);

  const me = await request(app).get("/me").set(student).expect(200);
  assert.equal(me.body.schoolName, "Al-Noor Model School");
});

test("official holidays can be moved but not deleted, and come back", async () => {
  const { addMissingOfficialHolidays } = require("../src/features/institution/official-holidays");
  const year = (await request(app).get("/academic-year").set(admin)).body;
  const eid = year.holidays.find((h) => h.name === "Eid al-Fitr");
  assert.equal(eid.isOfficial, true);
  assert.ok(year.holidays.some((h) => h.name === "Labour Day"));

  await request(app).delete(`/academic-year/holidays/${eid.id}`).set(admin).expect(409);

  // The moon was sighted a day later: the date moves, the name stays.
  const moved = await request(app)
    .patch(`/academic-year/holidays/${eid.id}`)
    .set(admin)
    .send({ name: "Renamed", type: "schoolBreak", start: "2027-03-10", end: "2027-03-13" })
    .expect(200);
  assert.equal(moved.body.name, "Eid al-Fitr");
  assert.equal(moved.body.start, "2027-03-10");

  // Deleted before they were protected: the server adds them back.
  const { query } = require("../src/db/database");
  await query("DELETE FROM holidays WHERE official_key = 'nowruz'");
  assert.equal(await addMissingOfficialHolidays(year.id), 1);
  // ...without touching the moved Eid.
  assert.equal(await addMissingOfficialHolidays(year.id), 0);
});

test("unknown paths are 404, not 'please sign in'", async () => {
  await request(app).get("/nothing-here").expect(404);
  await request(app).get("/institution").expect(401);
});
