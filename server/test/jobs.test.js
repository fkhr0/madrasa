const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { startTestApp, signIn, close, request } = require("./helpers");
const { query, queryOne } = require("../src/db/database");
const reminders = require("../src/jobs/reminders");
const { feeReminders } = require("../src/jobs/fees");
const { cleanUp, backUp } = require("../src/jobs/upkeep");
const { schoolCalendar, today, addDays, weekdayOf } = require("../src/features/attendance/school-days");
const { run } = require("../src/jobs/queue");

let app;
let parent;
let calendar;
before(async () => {
  app = await startTestApp();
  parent = { Authorization: `Bearer ${(await signIn(app, "PAR-2026-0142")).accessToken}` };
  calendar = await schoolCalendar("inst-001");
});
after(close);

const titles = async (who) => {
  const body = (await request(app).get("/notifications").set(who)).body;
  return (Array.isArray(body) ? body : body.items).map((n) => n.title);
};

/** The next school day from [from] days ahead. */
function schoolDay(from) {
  for (let d = from; ; d++) if (calendar.isSchoolDay(addDays(today(), d))) return addDays(today(), d);
}

test("exam reminders go to the class's families once", async () => {
  const day = schoolDay(0);
  await query(
    `INSERT INTO exams (institution_id, class_id, subject_id, type, title, date, start_time)
     VALUES ('inst-001', 'cls-5a', 'physics', 'monthly', 'Reminder test', $1, '09:40')`,
    [day],
  );

  assert.ok((await reminders.examsToday({ date: day })) >= 1);
  assert.equal(await reminders.examsToday({ date: day }), 0); // not twice
  assert.ok((await titles(parent)).includes("Physics monthly exam today at 09:40"));

  const evening = await reminders.eveningReminders({ date: addDays(day, -1) });
  assert.ok(evening.exams >= 1);
  assert.ok((await titles(parent)).includes("Physics monthly exam tomorrow at 09:40"));
});

test("personal reminders fire once and repeating ones move on", async () => {
  const due = new Date(Date.now() - 60_000);
  await query(
    `INSERT INTO tasks (user_id, id, title, due_at, is_reminder, repeat)
     VALUES ('PAR-2026-0142', 'job-r1', 'Pay the bus fee', $1, true, 'weekly')`,
    [due],
  );
  await reminders.taskReminders();
  await reminders.taskReminders();
  const sent = (await titles(parent)).filter((t) => t === "Pay the bus fee");
  assert.equal(sent.length, 1);

  const task = await queryOne("SELECT due_at FROM tasks WHERE id = 'job-r1'");
  assert.equal(Math.round((new Date(task.due_at) - due) / 86400000), 7);
});

test("a teacher is reminded about attendance 10 minutes into a lesson", async () => {
  const day = schoolDay(1);
  const lesson = await queryOne(
    `SELECT t.period, to_char(p.start_time + interval '12 minutes', 'HH24:MI') AS at
     FROM timetable_slots t JOIN periods p ON p.institution_id = 'inst-001' AND p.number = t.period
     WHERE t.class_id = 'cls-5a' AND t.weekday = $1 AND t.subject_id = 'math'`,
    [weekdayOf(day)],
  );
  assert.ok(lesson, "maths in 5th A that day");

  const sent = await reminders.attendanceReminders({ date: day, time: lesson.at });
  assert.ok(sent >= 1);
  assert.equal(await reminders.attendanceReminders({ date: day, time: lesson.at }), 0);

  const ahmed = { Authorization: `Bearer ${(await signIn(app, "TCH-2019-0031")).accessToken}` };
  assert.ok((await titles(ahmed)).includes("Take attendance: 5th Scientific – A"));
});

test("fee reminders: 3 days before an unpaid installment", async () => {
  // Zainab paid her first installment; her second is due 2027-01-01.
  const sent = await feeReminders({ date: "2026-12-29" });
  assert.ok(sent >= 1);
  assert.ok((await titles(parent)).includes("School fees due in 3 days"));
  assert.equal(await feeReminders({ date: "2026-12-29" }), 0);
});

test("nightly upkeep: removes unattached uploads, backs up the database", async () => {
  const file = await queryOne(
    `INSERT INTO files (institution_id, name, size_bytes, created_at)
     VALUES ('inst-001', 'forgotten.txt', 3, now() - interval '2 days') RETURNING id`,
  );
  const cleaned = await cleanUp();
  assert.ok(cleaned.files >= 1);
  assert.equal(await queryOne("SELECT id FROM files WHERE id = $1", [file.id]), null);

  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "school-backup-"));
  const backup = await backUp(folder);
  assert.ok(fs.statSync(backup).size > 1000);

  // Every scheduled job is defined.
  await run("announcements.due", {});
});

test("summaries: the office's day and each parent's week", async () => {
  const { dailySummary, weeklySummary } = require("../src/jobs/summaries");
  const admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };

  // A school day in the last week with attendance (the demo has 30 days of it).
  let day = addDays(today(), -1);
  while (!calendar.isSchoolDay(day)) day = addDays(day, -1);

  assert.ok((await dailySummary({ date: day })) >= 1);
  assert.equal(await dailySummary({ date: day }), 0);
  const office = (await request(app).get("/notifications").set(admin)).body;
  const daily = (Array.isArray(office) ? office : office.items).find((n) => n.title === "Today at school");
  assert.match(daily.body, /% present/);

  assert.ok((await weeklySummary({ date: day })) >= 1);
  assert.ok((await titles(parent)).includes("Zainab's week"));
});
