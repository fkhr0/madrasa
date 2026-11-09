const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { today, addDays, weekdayOf, schoolCalendar } = require("../src/features/attendance/school-days");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [
    ["admin", "ADM-2020-0001"],
    ["ahmed", "TCH-2019-0031"],
    ["parent", "PAR-2026-0142"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const AR = { "X-Language": "ar" };

test("errors and form checks in the caller's language", async () => {
  const ar = await request(app).get("/exams/nope/scores").set(as.ahmed).set(AR).expect(404);
  assert.equal(ar.body.error, "الامتحان غير موجود.");
  const en = await request(app).get("/exams/nope/scores").set(as.ahmed).set("X-Language", "en").expect(404);
  assert.equal(en.body.error, "Exam not found.");

  // A value inside the message, and zod's own check in Arabic.
  const day = await request(app)
    .put("/attendance/students/STU-2026-0142/excuses/2030-01-01")
    .set(as.admin)
    .set(AR)
    .send({})
    .expect(400);
  assert.equal(day.body.error, "هذا اليوم ليس يوم دوام.");
  const task = await request(app)
    .post("/tasks")
    .set(as.parent)
    .set(AR)
    .send({ id: "x", title: "", dueAt: new Date().toISOString() })
    .expect(400);
  assert.match(task.body.error, /^العنوان: /);
});

test("each person gets notifications in their own language", async () => {
  // The parent's app is in Arabic (it says so with its requests).
  await request(app).get("/me").set(as.parent).set(AR).expect(200);
  await new Promise((r) => setTimeout(r, 50)); // the language is saved in the background

  // The teacher (English) marks Zainab absent.
  const calendar = await schoolCalendar("inst-001");
  let date = today();
  const week = (await request(app).get("/timetable/classes/cls-5a").set(as.admin)).body;
  let maths;
  for (let back = 0; back < 14; back++) {
    date = addDays(today(), -back);
    maths = week.lessons.find((l) => l.weekday === weekdayOf(date) && l.subjectId === "math");
    if (calendar.isSchoolDay(date) && maths) break;
  }
  const url = `/attendance/classes/cls-5a/lessons/${date}/${maths.period}`;
  const sheet = (await request(app).get(url).set(as.ahmed)).body;
  const marks = Object.fromEntries(sheet.students.map((s) => [s.id, "present"]));
  marks["STU-2026-0142"] = "absent";
  await request(app).put(url).set(as.ahmed).send({ marks }).expect(200);

  const told = (await request(app).get("/notifications").set(as.parent).set(AR)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(items.some((n) => n.title === "غاب Zainab Haider"), "Arabic alert for the parent");
  // The same notification on a computer set to English.
  const inEnglish = (await request(app).get("/notifications").set(as.parent).set("X-Language", "en")).body;
  assert.ok(inEnglish.some((n) => n.title === "Zainab Haider was absent"), "and in English");

  // Activity: the same line in each reader's language, the name where it belongs.
  const ar = (await request(app).get("/activity?kind=attendance&limit=5").set(as.admin).set(AR)).body;
  assert.ok(ar.items.some((a) => a.summary.startsWith("سجّل Ahmed Kareem حضور 5th Scientific – A")));
  const en = (await request(app).get("/activity?kind=attendance&limit=5").set(as.admin)).body;
  assert.ok(en.items.some((a) => a.summary.startsWith("Ahmed Kareem took attendance for 5th Scientific – A")));
  // Searching in Arabic finds it too.
  const found = (await request(app).get(`/activity?q=${encodeURIComponent("سجّل")}`).set(as.admin)).body;
  assert.ok(found.items.length > 0);
});

test("money and words inside texts are translated too", async () => {
  await request(app).get("/me").set(as.parent).set(AR).expect(200);
  await new Promise((r) => setTimeout(r, 50));
  await request(app)
    .post("/finance/accounts/STU-2026-0142/payments")
    .set(as.admin)
    .send({ amount: 250000, method: "cash" })
    .expect(201);
  const told = (await request(app).get("/notifications").set(as.parent).set(AR)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(items.some((n) => n.title === "تم استلام دفعة · 250,000 د.ع"));

  // Official holidays and day-off reasons in Arabic.
  const year = (await request(app).get("/academic-year").set(as.parent).set(AR)).body;
  assert.ok(year.holidays.some((h) => h.name === "عيد الفطر"));
});
