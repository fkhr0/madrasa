const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [role, id] of [
    ["admin", "ADM-2020-0001"],
    ["student", "STU-2026-0142"], // 5th Scientific – A
    ["parent", "PAR-2026-0142"], // Zainab's father
    ["teacher", "TCH-2019-0031"], // Mathematics, every class
    ["biology", "TCH-2019-0045"], // not in 5th Scientific – B
    ["driver", "DRV-2024-0012"],
  ]) {
    as[role] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const titles = async (who) =>
  (await request(app).get("/announcements").set(who).expect(200)).body.map(
    (a) => a.title,
  );

test("each role reads what is meant for them, pinned first", async () => {
  const student = await titles(as.student);
  assert.equal(student[0], "Mid-term exams timetable published");
  assert.ok(student.includes("Chemistry lab moved to Thursday"));
  assert.ok(!student.includes("Parent–teacher meeting"));

  const parent = await titles(as.parent);
  assert.ok(parent.includes("Parent–teacher meeting"));
  assert.ok(parent.includes("Class photo day")); // their child's class

  const driver = await titles(as.driver);
  assert.ok(!driver.includes("Class photo day"));
  assert.equal((await titles(as.admin)).length, 5);
});

test("a teacher announces only to classes they teach", async () => {
  const post = (who, body) =>
    request(app)
      .post("/announcements")
      .set(who)
      .send({ title: "Quiz on Sunday", body: "Chapter 4.", ...body });

  await post(as.teacher, { audience: "school" }).expect(403);
  await post(as.biology, {
    audience: "class",
    className: "5th Scientific – B",
  }).expect(403);

  const created = await post(as.teacher, {
    audience: "class",
    className: "5th Scientific – A",
    isPinned: true, // ignored for teachers
  }).expect(201);
  assert.equal(created.body.authorName, "Ahmed Kareem");
  assert.equal(created.body.className, "5th Scientific – A");
  assert.equal(created.body.isPinned, false);
  assert.ok((await titles(as.student)).includes("Quiz on Sunday"));

  // Another teacher can't change it; its author can.
  await request(app)
    .delete(`/announcements/${created.body.id}`)
    .set(as.biology)
    .expect(403);
  await request(app)
    .delete(`/announcements/${created.body.id}`)
    .set(as.teacher)
    .expect(204);
});

test("an administrator edits, pins, schedules and deletes", async () => {
  const later = new Date(Date.now() + 86400000).toISOString();
  const scheduled = await request(app)
    .post("/announcements")
    .set(as.admin)
    .send({ title: "Uniform reminder", body: "Winter uniform from Sunday.", audience: "school", publishedAt: later })
    .expect(201);
  assert.ok(!(await titles(as.student)).includes("Uniform reminder"));

  const [first] = (await request(app).get("/announcements").set(as.admin)).body;
  const edited = await request(app)
    .patch(`/announcements/${first.id}`)
    .set(as.admin)
    .send({ ...first, title: "Exams timetable (updated)", isPinned: false })
    .expect(200);
  assert.equal(edited.body.isPinned, false);

  await request(app).delete(`/announcements/${scheduled.body.id}`).set(as.admin).expect(204);
  await request(app).delete(`/announcements/${scheduled.body.id}`).set(as.admin).expect(404);
});
