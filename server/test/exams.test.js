const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { today, addDays, schoolCalendar } = require("../src/features/attendance/school-days");

let app;
const as = {};
let calendar;
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [
    ["admin", "ADM-2020-0001"],
    ["zainab", "STU-2026-0142"],
    ["ahmed", "TCH-2019-0031"],
    ["sara", "TCH-2019-0040"],
    ["parent", "PAR-2026-0142"],
    ["otherParent", "PAR-2026-0150"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
  calendar = await schoolCalendar("inst-001");
});
after(close);

/** The first school day [from] days from today or after (or before, if negative). */
function schoolDay(from) {
  const step = from < 0 ? -1 : 1;
  for (let d = from; ; d += step) {
    if (calendar.isSchoolDay(addDays(today(), d))) return addDays(today(), d);
  }
}

const notifications = async (who) => {
  const body = (await request(app).get("/notifications").set(who)).body;
  return Array.isArray(body) ? body : body.items;
};

test("a student sees her class's exams, scores only once published", async () => {
  const exams = (await request(app).get("/exams/students/STU-2026-0142").set(as.zainab).expect(200)).body;

  const functions = exams.find((e) => e.title === "Functions test");
  assert.equal(functions.score, 42);
  assert.equal(functions.maxScore, 50);
  assert.equal(functions.subjectName, "Mathematics");
  assert.equal(functions.teacherName, "Ahmed Kareem");

  const upcoming = exams.find((e) => e.subjectId === "math" && e.type === "monthly" && !e.published);
  assert.equal(upcoming.score, null);
  assert.deepEqual(upcoming.topics, ["Quadratic equations", "Functions", "Inequalities"]);

  await request(app).get("/exams/students/STU-2026-0142").set(as.parent).expect(200);
  await request(app).get("/exams/students/STU-2026-0142").set(as.otherParent).expect(404);
});

test("a teacher sees and schedules exams only for his subjects", async () => {
  const mine = (await request(app).get("/exams/classes/cls-5a").set(as.ahmed).expect(200)).body;
  assert.ok(mine.length > 0);
  assert.ok(mine.every((e) => e.subjectId === "math"));
  const all = (await request(app).get("/exams/classes/cls-5a").set(as.admin).expect(200)).body;
  assert.ok(all.length > mine.length);

  const exam = {
    subjectId: "math",
    type: "quiz",
    title: "Inequalities quiz",
    date: schoolDay(1),
    startTime: "09:40",
    durationMinutes: 20,
    room: "Room 204",
    topics: ["Inequalities"],
    maxScore: 10,
  };
  await request(app).post("/exams/classes/cls-5a").set(as.ahmed).send({ ...exam, subjectId: "physics" }).expect(403);
  await request(app).post("/exams/classes/cls-5a").set(as.zainab).send(exam).expect(403);
  await request(app)
    .post("/exams/classes/cls-5a")
    .set(as.ahmed)
    .send({ ...exam, date: addDays(today(), 400) })
    .expect(400);

  const created = await request(app).post("/exams/classes/cls-5a").set(as.ahmed).send(exam).expect(201);
  assert.equal(created.body.title, "Inequalities quiz");
  assert.equal(created.body.published, false);

  // Students and their parents hear about it.
  assert.ok((await notifications(as.parent)).some((n) => n.title === "New Mathematics quiz"));

  const moved = await request(app)
    .patch(`/exams/${created.body.id}`)
    .set(as.ahmed)
    .send({ ...exam, room: "Hall A" })
    .expect(200);
  assert.equal(moved.body.room, "Hall A");

  await request(app).delete(`/exams/${created.body.id}`).set(as.sara).expect(403);
  await request(app).delete(`/exams/${created.body.id}`).set(as.ahmed).expect(204);
  await request(app).delete(`/exams/${created.body.id}`).set(as.ahmed).expect(404);
});

test("scores: checked, published, and students are told", async () => {
  const exam = (
    await request(app)
      .post("/exams/classes/cls-5a")
      .set(as.ahmed)
      .send({ subjectId: "math", type: "quiz", title: "Surprise quiz", date: schoolDay(-1), maxScore: 20 })
      .expect(201)
  ).body;
  const url = `/exams/${exam.id}/scores`;

  const sheet = (await request(app).get(url).set(as.ahmed).expect(200)).body;
  assert.ok(sheet.students.every((s) => s.score === null));

  await request(app).put(url).set(as.ahmed).send({ scores: { "STU-2026-0142": 25 } }).expect(400);
  await request(app).put(url).set(as.ahmed).send({ scores: { "STU-2026-0153": 10 } }).expect(400);
  await request(app).put(url).set(as.sara).send({ scores: {} }).expect(403);

  // Before publishing, Zainab doesn't see her score.
  const hidden = (await request(app).get("/exams/students/STU-2026-0142").set(as.zainab)).body;
  assert.equal(hidden.find((e) => e.id === exam.id).score, null);

  const saved = await request(app)
    .put(url)
    .set(as.ahmed)
    .send({ scores: { "STU-2026-0142": 18.5, "STU-2026-0150": null } })
    .expect(200);
  assert.equal(saved.body.exam.published, true);
  assert.equal(saved.body.students.find((s) => s.id === "STU-2026-0142").score, 18.5);

  const shown = (await request(app).get("/exams/students/STU-2026-0142").set(as.zainab)).body;
  assert.equal(shown.find((e) => e.id === exam.id).score, 18.5);
  assert.ok((await notifications(as.parent)).some((n) => n.title === "Mathematics: 18.5 / 20"));

  // "Out of" can't drop below a score already given.
  await request(app)
    .patch(`/exams/${exam.id}`)
    .set(as.ahmed)
    .send({ subjectId: "math", type: "quiz", title: "Surprise quiz", date: exam.date, maxScore: 10 })
    .expect(400);
});

test("no scores before the exam day", async () => {
  const exam = (
    await request(app)
      .post("/exams/classes/cls-5a")
      .set(as.admin)
      .send({ subjectId: "physics", type: "monthly", title: "Later", date: schoolDay(1) })
      .expect(201)
  ).body;
  await request(app)
    .put(`/exams/${exam.id}/scores`)
    .set(as.admin)
    .send({ scores: { "STU-2026-0142": 50 } })
    .expect(400);
});

test("the teacher's class list shows averages and exams waiting for scores", async () => {
  const students = (await request(app).get("/teaching/classes/cls-5a/students").set(as.ahmed)).body;
  const zainab = students.find((s) => s.id === "STU-2026-0142");
  assert.ok(zainab.average > 50 && zainab.average <= 100);

  const classes = (await request(app).get("/teaching/classes").set(as.ahmed)).body;
  assert.equal(typeof classes[0].toGradeCount, "number");
});
