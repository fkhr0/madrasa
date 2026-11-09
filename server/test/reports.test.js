const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
let admin;
let teacher;
before(async () => {
  app = await startTestApp();
  admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };
  teacher = { Authorization: `Bearer ${(await signIn(app, "TCH-2019-0031")).accessToken}` };
});
after(close);

test("today at school: real counts", async () => {
  const today = (await request(app).get("/reports/today").set(admin).expect(200)).body;
  assert.ok(today.students > 10);
  assert.ok(today.teachers >= 8);
  assert.equal(today.classes, 4);
  assert.equal(typeof today.presentToday, "number");
  assert.ok(Array.isArray(today.classesMissingAttendance));

  await request(app).get("/reports/today").set(teacher).expect(403);
});

test("insights for the term come from the demo data", async () => {
  const term = (await request(app).get("/reports/insights?period=term").set(admin).expect(200)).body;
  assert.ok(term.attendanceRate > 0.8 && term.attendanceRate <= 1);
  assert.equal(term.attendanceByDay.length, 5);
  assert.equal(term.attendanceByDay[0].label, "Sun");
  assert.ok(term.attendanceByClass.some((c) => c.label === "5th Scientific – A"));
  assert.ok(term.averageGrade > 40 && term.averageGrade <= 100);
  assert.ok(term.gradeBySubject.some((s) => s.label === "Mathematics"));
  assert.ok(term.assignmentsGiven >= 1);

  await request(app).get("/reports/insights?period=year").set(admin).expect(400);
  const week = (await request(app).get("/reports/insights?period=week").set(admin).expect(200)).body;
  assert.ok(week.from <= week.to);
});
