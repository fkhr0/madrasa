const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [
    ["admin", "ADM-2020-0001"],
    ["zainab", "STU-2026-0142"],
    ["ahmed", "TCH-2019-0031"],
    ["parent", "PAR-2026-0142"],
    ["otherParent", "PAR-2026-0150"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const SUNDAY = 7;
const MONDAY = 1;

test("a student sees her class's week with bell times and teachers", async () => {
  const res = await request(app)
    .get("/timetable/people/STU-2026-0142/week")
    .set(as.zainab)
    .expect(200);

  assert.equal(res.body.periods.length, 6);
  assert.deepEqual(res.body.periods[0], { number: 1, start: "08:00", end: "08:45" });

  const sunday = res.body.lessons.filter((l) => l.weekday === SUNDAY);
  assert.deepEqual(
    sunday.map((l) => l.subjectId),
    ["islamic", "math", "physics", "arabic", "english", "biology"],
  );
  const maths = sunday[1];
  assert.equal(maths.start, "08:50");
  assert.equal(maths.teacherName, "Ahmed Kareem");
  assert.equal(maths.room, "Room 204");
  assert.equal(maths.icon, "math");
});

test("a teacher sees every lesson he teaches, in several classes", async () => {
  const res = await request(app)
    .get("/timetable/people/TCH-2019-0031/week")
    .set(as.ahmed)
    .expect(200);

  assert.ok(res.body.lessons.every((l) => l.subjectId === "math"));
  const sunday = res.body.lessons.filter((l) => l.weekday === SUNDAY);
  assert.deepEqual(
    sunday.map((l) => [l.period, l.className]),
    [
      [2, "5th Scientific – A"],
      [3, "5th Scientific – B"],
      [5, "4th Scientific – A"],
    ],
  );
});

test("the demo week never puts a teacher in two classes at once", async () => {
  const classes = (await request(app).get("/academics/classes").set(as.admin)).body;
  const seen = new Set();
  for (const c of classes) {
    const week = (await request(app).get(`/timetable/classes/${c.id}`).set(as.admin)).body;
    for (const l of week.lessons.filter((l) => l.teacherId)) {
      const key = `${l.teacherId}/${l.weekday}/${l.period}`;
      assert.ok(!seen.has(key), `${l.teacherName} twice at ${key}`);
      seen.add(key);
    }
  }
});

test("only the person, their parents and their school's admin can read a week", async () => {
  await request(app).get("/timetable/people/STU-2026-0142/week").set(as.parent).expect(200);
  await request(app).get("/timetable/people/STU-2026-0142/week").set(as.admin).expect(200);
  await request(app).get("/timetable/people/STU-2026-0142/week").set(as.otherParent).expect(404);
  await request(app).get("/timetable/people/TCH-2019-0031/week").set(as.zainab).expect(404);
  await request(app).get("/timetable/classes/cls-5a").set(as.ahmed).expect(403);
});

test("admin places, moves and removes a lesson; a busy teacher is refused", async () => {
  // Monday period 1: Mr. Ahmed teaches maths in 6th C.
  const clash = await request(app)
    .put(`/timetable/classes/cls-5a/lessons/${MONDAY}/1`)
    .set(as.admin)
    .send({ subjectId: "math", room: "Room 204" })
    .expect(409);
  assert.match(clash.body.error, /Ahmed Kareem already teaches 6th Scientific – C/);

  // Not a study day / not a period / not a subject of the class.
  await request(app)
    .put("/timetable/classes/cls-5a/lessons/5/1")
    .set(as.admin)
    .send({ subjectId: "arabic" })
    .expect(400);
  await request(app)
    .put(`/timetable/classes/cls-5a/lessons/${MONDAY}/9`)
    .set(as.admin)
    .send({ subjectId: "arabic" })
    .expect(400);
  await request(app)
    .put(`/timetable/classes/cls-5a/lessons/${MONDAY}/1`)
    .set(as.admin)
    .send({ subjectId: "history" })
    .expect(400);

  // Thursday period 5 is free in 5th A.
  const placed = await request(app)
    .put("/timetable/classes/cls-5a/lessons/4/5")
    .set(as.admin)
    .send({ subjectId: "english", room: "Room 110" })
    .expect(200);
  assert.ok(placed.body.workingDays.includes(4));
  assert.ok(placed.body.lessons.some((l) => l.weekday === 4 && l.period === 5));

  await request(app).delete("/timetable/classes/cls-5a/lessons/4/5").set(as.admin).expect(200);
  await request(app).delete("/timetable/classes/cls-5a/lessons/4/5").set(as.admin).expect(404);
});

test("giving a subject to a teacher who is busy at its times is refused", async () => {
  // A teacher who teaches another class at the time of one of 5th A's
  // physics lessons can't take 5th A's physics.
  const fiveA = (await request(app).get("/timetable/classes/cls-5a").set(as.admin)).body;
  const physics = fiveA.lessons.filter((l) => l.subjectId === "physics");
  let busyTeacher = null;
  for (const id of ["cls-4a", "cls-5b", "cls-6c"]) {
    const other = (await request(app).get(`/timetable/classes/${id}`).set(as.admin)).body;
    busyTeacher ??= other.lessons.find(
      (l) =>
        l.teacherId &&
        physics.some((p) => p.weekday === l.weekday && p.period === l.period),
    );
  }
  assert.ok(busyTeacher);
  const refused = await request(app)
    .put("/academics/classes/cls-5a/subjects/physics")
    .set(as.admin)
    .send({ teacherId: busyTeacher.teacherId })
    .expect(409);
  assert.match(refused.body.error, /Move one of the lessons first/);

  // 5th B's computer lessons have no teacher yet; Mr. Bilal is free then.
  const fiveB = (await request(app).get("/timetable/classes/cls-5b").set(as.admin)).body;
  assert.ok(fiveB.lessons.some((l) => l.subjectId === "computer" && !l.teacherId));

  await request(app)
    .put("/academics/classes/cls-5b/subjects/computer")
    .set(as.admin)
    .send({ teacherId: "TCH-2019-0046" })
    .expect(200);
});

test("bell times: checked, and cutting periods with lessons asks first", async () => {
  const five = [
    { start: "08:00", end: "08:45" },
    { start: "08:50", end: "09:35" },
    { start: "09:40", end: "10:25" },
    { start: "10:45", end: "11:30" },
    { start: "11:35", end: "12:20" },
  ];

  await request(app)
    .put("/timetable/periods")
    .set(as.admin)
    .send({ periods: [{ start: "09:00", end: "08:00" }] })
    .expect(400);
  await request(app)
    .put("/timetable/periods")
    .set(as.admin)
    .send({ periods: [five[1], five[0]] })
    .expect(400);
  await request(app).put("/timetable/periods").set(as.zainab).send({ periods: five }).expect(403);

  const asked = await request(app)
    .put("/timetable/periods")
    .set(as.admin)
    .send({ periods: five })
    .expect(409);
  assert.match(asked.body.error, /after period 5/);

  const saved = await request(app)
    .put("/timetable/periods")
    .set(as.admin)
    .send({ periods: five, removeLessons: true })
    .expect(200);
  assert.equal(saved.body.length, 5);

  const week = (await request(app).get("/timetable/people/STU-2026-0142/week").set(as.zainab)).body;
  assert.ok(week.lessons.every((l) => l.period <= 5));
});

test("the cached week changes the moment the office changes the timetable", async () => {
  const week = async () =>
    (await request(app).get("/timetable/people/STU-2026-0142/week").set(as.zainab).expect(200)).body;
  const roomOf = (body) => body.lessons.find((l) => l.weekday === SUNDAY && l.period === 2)?.room;

  const before = await week(); // now cached
  const lesson = before.lessons.find((l) => l.weekday === SUNDAY && l.period === 2);
  await request(app)
    .put(`/timetable/classes/cls-5a/lessons/${SUNDAY}/2`)
    .set(as.admin)
    .send({ subjectId: lesson.subjectId, room: "Lab 3" })
    .expect(200);

  assert.equal(roomOf(await week()), "Lab 3");
});
