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
    ["fatima", "STU-2026-0150"],
    ["ali", "STU-2026-0153"], // 5th B
    ["ahmed", "TCH-2019-0031"],
    ["omar", "TCH-2019-0041"],
    ["parent", "PAR-2026-0142"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
  calendar = await schoolCalendar("inst-001");
});
after(close);

/** The latest school day before today (the demo has attendance on it). */
function lastSchoolDay() {
  let day = addDays(today(), -1);
  while (!calendar.isSchoolDay(day)) day = addDays(day, -1);
  return day;
}

const get = async (who, url) => (await request(app).get(url).set(who).expect(200)).body;

test("the demo's history is in the log, newest first, and pages back", async () => {
  const page = await get(as.admin, "/activity?limit=20");
  assert.equal(page.items.length, 20);
  assert.ok(page.next);
  for (let i = 1; i < page.items.length; i++) {
    assert.ok(new Date(page.items[i - 1].at) >= new Date(page.items[i].at));
  }
  const older = await get(as.admin, `/activity?limit=20&before=${encodeURIComponent(page.next)}`);
  assert.ok(new Date(older.items[0].at) <= new Date(page.next));
});

test("filters: day, kind, person, class, text", async () => {
  const day = lastSchoolDay();
  const taken = await get(as.admin, `/activity?date=${day}&kind=attendance`);
  assert.ok(taken.items.length > 0);
  assert.ok(taken.items.every((a) => a.kind === "attendance"));

  const byAhmed = await get(as.admin, "/activity?actorId=TCH-2019-0031&kind=attendance");
  assert.ok(byAhmed.items.every((a) => a.actorName === "Ahmed Kareem"));

  const fiveA = await get(as.admin, "/activity?classId=cls-5a&kind=homework");
  assert.ok(fiveA.items.length > 0 && fiveA.items.every((a) => a.className === "5th Scientific – A"));

  const search = await get(as.admin, "/activity?q=Zainab");
  assert.ok(search.items.length > 0 && search.items.every((a) => /Zainab/.test(a.summary)));

  await request(app).get("/activity?date=yesterday").set(as.admin).expect(400);
});

test("each role sees only its part", async () => {
  // A new action is logged with who did it.
  await request(app)
    .put("/attendance/students/STU-2026-0142/excuses/" + lastSchoolDay())
    .set(as.admin)
    .send({ note: "Doctor's visit" })
    .expect(204);
  const office = await get(as.admin, "/activity?kind=attendance&limit=5");
  assert.match(office.items[0].summary, /excused Zainab Haider on .*Doctor's visit/);

  // Zainab's parent sees it; Fatima doesn't.
  assert.ok((await get(as.parent, "/activity?q=Doctor")).items.length === 1);
  assert.equal((await get(as.fatima, "/activity?q=Doctor")).items.length, 0);

  // Students see their own grades and the class's news, never a classmate's lines.
  const fatima = await get(as.fatima, "/activity?limit=100");
  assert.ok(fatima.items.every((a) => !/Zainab/.test(a.summary)));
  assert.ok(fatima.items.some((a) => a.kind === "homework"));
  // A student of 5th B sees nothing of 5th A.
  const ali = await get(as.ali, "/activity?limit=100");
  assert.ok(ali.items.every((a) => a.className !== "5th Scientific – A"));

  // A teacher sees their classes, not the office's money.
  const ahmed = await get(as.ahmed, "/activity?limit=100");
  assert.ok(ahmed.items.length > 0);
  assert.ok(ahmed.items.every((a) => a.kind !== "finance"));
});

test("the school's day: periods, who took attendance and when, totals", async () => {
  const day = lastSchoolDay();
  const school = await get(as.admin, `/days/${day}/school`);
  assert.equal(school.isSchoolDay, true);
  assert.ok(school.periods.length >= 4);
  assert.ok(school.periods.every((p) => p.state === "done"));

  const fiveA = school.periods[0].lessons.find((l) => l.className === "5th Scientific – A");
  assert.ok(fiveA.attendance, "5th A's first lesson was taken");
  assert.ok(fiveA.attendance.takenBy && fiveA.attendance.takenAt);
  assert.ok(school.totals.present > 0);
  assert.ok(school.totals.lessonsMissing > 0); // the demo only marks 5th A

  // A weekend says why.
  let off = today();
  while (calendar.isSchoolDay(off)) off = addDays(off, 1);
  const weekend = await get(as.admin, `/days/${off}/school`);
  assert.equal(weekend.isSchoolDay, false);
  assert.ok(weekend.dayOff);

  await request(app).get(`/days/${day}/school`).set(as.ahmed).expect(403);
});

test("a teacher's day and a student's day", async () => {
  const day = lastSchoolDay();
  const ahmed = await get(as.ahmed, `/days/${day}/teacher`);
  assert.ok(ahmed.periods.every((p) => p.lessons.every((l) => l.subjectName === "Mathematics")));

  const zainab = await get(as.parent, `/days/${day}/students/STU-2026-0142`);
  assert.equal(zainab.student.name, "Zainab Haider");
  assert.ok(zainab.periods.length >= 4);
  const first = zainab.periods[0].lessons[0];
  assert.ok(first.mark && first.mark.status && first.mark.markedBy);
  assert.ok(zainab.day.status);

  await request(app).get(`/days/${day}/students/STU-2026-0142`).set(as.fatima).expect(404);
});
