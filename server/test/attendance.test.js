const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { studentDays } = require("../src/features/attendance/student-days");
const {
  today,
  addDays,
  weekdayOf,
  schoolCalendar,
} = require("../src/features/attendance/school-days");

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

/** The latest school day, [from] days ago or earlier, with a maths lesson in 5th A. */
async function mathsDay(from = 0) {
  const week = (await request(app).get("/timetable/classes/cls-5a").set(as.admin)).body;
  for (let back = from; back < from + 14; back++) {
    const date = addDays(today(), -back);
    const maths = week.lessons.find(
      (l) => l.weekday === weekdayOf(date) && l.subjectId === "math",
    );
    if (calendar.isSchoolDay(date) && maths) return { date, period: maths.period };
  }
  throw new Error("No maths lesson in the last two weeks");
}

test("a day from its lesson marks", () => {
  const mark = (date, period, status, subjectName) => ({ date, period, status, subjectName });
  const days = studentDays(
    [
      mark("2026-11-02", 1, "present", "Maths"),
      mark("2026-11-02", 2, "late", "Physics"),
      mark("2026-11-03", 1, "absent", "Maths"),
      mark("2026-11-03", 2, "absent", "Physics"),
      mark("2026-11-04", 1, "present", "Maths"),
      mark("2026-11-04", 2, "absent", "Physics"),
      mark("2026-11-05", 1, "absent", "Maths"),
      mark("2026-11-08", 1, "present", "Maths"),
    ],
    [{ date: "2026-11-05", note: "Medical note" }],
  );

  assert.deepEqual(
    days.map((d) => [d.date, d.status, d.note]),
    [
      ["2026-11-08", "present", null],
      ["2026-11-05", "excused", "Medical note"],
      ["2026-11-04", "present", "Missed 1 of 2 lessons: Physics"],
      ["2026-11-03", "absent", null],
      ["2026-11-02", "late", "Late to Physics"],
    ],
  );
  assert.equal(days[2].lessons.length, 2);
});

test("a student and her parent read her days; others can't", async () => {
  const res = await request(app).get("/attendance/students/STU-2026-0142").set(as.zainab).expect(200);
  assert.ok(res.body.days.length > 0);
  assert.ok(res.body.days.every((d) => d.date >= res.body.from && d.date <= res.body.to));
  for (const day of res.body.days.filter((d) => d.status === "excused")) {
    assert.equal(day.note, "Medical note received");
  }

  await request(app).get("/attendance/students/STU-2026-0142").set(as.parent).expect(200);
  await request(app).get("/attendance/students/STU-2026-0142").set(as.otherParent).expect(404);
  await request(app).get("/attendance/students/STU-2026-0142").set(as.ahmed).expect(404);
});

test("a teacher sees only his lessons of the day; the admin sees all", async () => {
  const { date, period } = await mathsDay();

  const mine = await request(app)
    .get(`/attendance/classes/cls-5a/lessons?date=${date}`)
    .set(as.ahmed)
    .expect(200);
  assert.equal(mine.body.isSchoolDay, true);
  assert.deepEqual(mine.body.lessons.map((l) => l.subjectName), ["Mathematics"]);
  assert.equal(mine.body.lessons[0].period, period);

  const all = await request(app)
    .get(`/attendance/classes/cls-5a/lessons?date=${date}`)
    .set(as.admin)
    .expect(200);
  assert.ok(all.body.lessons.length > 1);

  await request(app).get("/attendance/classes/cls-5a/lessons").set(as.zainab).expect(403);
});

test("the teacher marks a lesson; parents of an absent student are told", async () => {
  const { date, period } = await mathsDay();
  const url = `/attendance/classes/cls-5a/lessons/${date}/${period}`;

  const sheet = (await request(app).get(url).set(as.ahmed).expect(200)).body;
  assert.equal(sheet.lesson.subjectName, "Mathematics");
  const marks = Object.fromEntries(sheet.students.map((s) => [s.id, "present"]));
  marks["STU-2026-0142"] = "absent";

  // Everyone must be marked; only the lesson's teacher marks it.
  const { "STU-2026-0150": _, ...withoutFatima } = marks;
  await request(app).put(url).set(as.ahmed).send({ marks: withoutFatima }).expect(400);
  await request(app).put(url).set(as.sara).send({ marks }).expect(403);

  const saved = await request(app).put(url).set(as.ahmed).send({ marks }).expect(200);
  assert.equal(saved.body.students.find((s) => s.id === "STU-2026-0142").status, "absent");

  const told = await request(app).get("/notifications").set(as.parent).expect(200);
  const list = Array.isArray(told.body) ? told.body : told.body.items;
  assert.ok(list.some((n) => n.title === "Zainab Haider was absent"));

  const day = (await request(app).get("/attendance/students/STU-2026-0142").set(as.zainab)).body
    .days.find((d) => d.date === date);
  // Absent only when she missed every lesson marked that day; otherwise the
  // day counts as attended and the note names the missed lesson.
  if (day.lessons.every((l) => l.status === "absent")) {
    assert.equal(day.status, "absent");
  } else {
    assert.notEqual(day.status, "absent");
    assert.match(day.note, /Missed \d+ of \d+ lessons: .*Mathematics/);
  }
  assert.ok(day.lessons.some((l) => l.subjectName === "Mathematics" && l.status === "absent"));
});

test("no marking ahead or on days off; a teacher can't go back more than a week", async () => {
  const tomorrow = addDays(today(), 1);
  await request(app)
    .put(`/attendance/classes/cls-5a/lessons/${tomorrow}/1`)
    .set(as.admin)
    .send({ marks: {} })
    .expect(400);

  const old = await mathsDay(8);
  const url = `/attendance/classes/cls-5a/lessons/${old.date}/${old.period}`;
  await request(app).get(url).set(as.ahmed).expect(403);
  // The office can still correct it.
  await request(app).get(url).set(as.admin).expect(200);
});

test("the office excuses a day, and can take it back", async () => {
  const { date } = await mathsDay();
  const url = `/attendance/students/STU-2026-0142/excuses/${date}`;

  await request(app).put(url).set(as.ahmed).send({ note: "x" }).expect(403);
  await request(app).put(url).set(as.admin).send({ note: "Family emergency" }).expect(204);

  const days = (await request(app).get("/attendance/students/STU-2026-0142").set(as.parent)).body.days;
  const day = days.find((d) => d.date === date);
  assert.equal(day.status, "excused");
  assert.equal(day.note, "Family emergency");

  await request(app).delete(url).set(as.admin).expect(204);
  await request(app).delete(url).set(as.admin).expect(404);
});

test("a teacher's classes and students with their attendance", async () => {
  const classes = (await request(app).get("/teaching/classes").set(as.ahmed).expect(200)).body;
  assert.deepEqual(
    classes.map((c) => c.name),
    ["4th Scientific – A", "5th Scientific – A", "5th Scientific – B", "6th Scientific – C"],
  );
  const fiveA = classes.find((c) => c.id === "cls-5a");
  assert.equal(fiveA.subject.name, "Mathematics");
  assert.equal(fiveA.room, "Room 204");
  assert.ok(fiveA.studentCount >= 4);

  const students = (await request(app).get("/teaching/classes/cls-5a/students").set(as.ahmed).expect(200)).body;
  const zainab = students.find((s) => s.id === "STU-2026-0142");
  assert.ok(zainab.attendanceRate < 100); // absent in maths above

  await request(app).get("/teaching/classes/cls-5a/students").set(as.sara).expect(200);
  await request(app).get("/teaching/classes/cls-5a/students").set(as.admin).expect(403);
});

test("a planned absence: excused ahead, listed, and no absence alert that day", async () => {
  // The next school day after today.
  let day = addDays(today(), 1);
  while (!calendar.isSchoolDay(day)) day = addDays(day, 1);

  await request(app)
    .put(`/attendance/students/STU-2026-0150/excuses/${day}`)
    .set(as.admin)
    .send({ note: "Doctor's appointment" })
    .expect(204);

  const planned = (await request(app).get("/attendance/students/STU-2026-0150/excuses/planned").set(as.admin).expect(200)).body;
  assert.deepEqual(planned.map((p) => [p.date, p.note]), [[day, "Doctor's appointment"]]);
  await request(app).get("/attendance/students/STU-2026-0150/excuses/planned").set(as.parent).expect(404);

  // Today with an excuse: marking her absent doesn't alert her family.
  const { date, period } = await mathsDay();
  await request(app).put(`/attendance/students/STU-2026-0150/excuses/${date}`).set(as.admin).send({ note: "Travel" }).expect(204);
  const url = `/attendance/classes/cls-5a/lessons/${date}/${period}`;
  const sheet = (await request(app).get(url).set(as.ahmed)).body;
  const marks = Object.fromEntries(sheet.students.map((s) => [s.id, "present"]));
  marks["STU-2026-0150"] = "absent";
  await request(app).put(url).set(as.ahmed).send({ marks }).expect(200);

  const fatima = { Authorization: `Bearer ${(await signIn(app, "STU-2026-0150")).accessToken}` };
  const told = (await request(app).get("/notifications").set(fatima)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(!items.some((n) => n.title === "Fatima Ali was absent"));
});
