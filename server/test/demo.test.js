// "Try the demo": sign in without a password, protected demo accounts, and
// the nightly reset that makes the demo school again (in Arabic).
process.env.DEMO_MODE = "true";
process.env.DEMO_LANGUAGE = "ar";
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, close, request } = require("./helpers");
const { query, queryOne } = require("../src/db/database");
const { resetDemoSchool } = require("../src/features/auth/demo");

let app;
before(async () => (app = await startTestApp()));
after(close);

const enterAs = async (role) => (await request(app).post("/auth/demo").send({ role }).expect(200)).body;

test("anyone can open the demo as any role, without a password", async () => {
  const { roles } = (await request(app).get("/auth/demo").expect(200)).body;
  assert.deepEqual(roles, ["student", "parent", "teacher", "admin", "driver"]);

  const { user, accessToken } = await enterAs("parent");
  assert.equal(user.id, "PAR-2026-0142");
  assert.equal(user.isDemo, true);
  await request(app).get("/me").set({ Authorization: `Bearer ${accessToken}` }).expect(200);
  await request(app).post("/auth/demo").send({ role: "superuser" }).expect(400);
});

test("a visitor can't spoil the demo for the next one", async () => {
  const student = { Authorization: `Bearer ${(await enterAs("student")).accessToken}` };
  const admin = { Authorization: `Bearer ${(await enterAs("admin")).accessToken}` };

  await request(app).post("/me/password").set(student).send({ currentPassword: "x", newPassword: "12345678" }).expect(403);
  await request(app).post("/me/sign-out-everywhere").set(student).send({}).expect(403);
  await request(app).post("/me/deletion-request").set(student).send({}).expect(403);
  // Not even the demo office can remove or lock the demo accounts.
  await request(app).delete("/people/TCH-2019-0031").set(admin).expect(403);
  await request(app).post("/people/STU-2026-0142/active").set(admin).send({ isActive: false }).expect(403);
  await request(app).post("/people/STU-2026-0142/reset-password").set(admin).expect(403);
});

test("every night the demo school is made again, in Arabic; real schools stay as they are", async () => {
  // A real school on the same server, with an English subject.
  await query("INSERT INTO institutions (id, name, type, city) VALUES ('real-1', 'Baghdad College', 'school', 'Baghdad')");
  await query("INSERT INTO subjects (id, institution_id, name) VALUES ('real-math', 'real-1', 'Mathematics')");
  // A visitor changed something in the demo.
  await query("UPDATE institutions SET name = 'Changed by a visitor' WHERE id = 'inst-001'");

  const added = await resetDemoSchool();
  assert.ok(added.includes("activity history"));

  assert.equal((await queryOne("SELECT name FROM institutions WHERE id = 'inst-001'")).name, "إعدادية النور");
  assert.equal((await queryOne("SELECT name FROM users WHERE id = 'STU-2026-0142'")).name, "زينب حيدر");
  assert.equal((await queryOne("SELECT class_name FROM users WHERE id = 'STU-2026-0142'")).class_name, "الخامس العلمي – أ");
  assert.equal((await queryOne("SELECT name FROM classes WHERE id = 'cls-5a'")).name, "الخامس العلمي – أ");
  assert.ok((await queryOne("SELECT count(*) AS n FROM activity_log WHERE institution_id = 'inst-001'")).n > 0);

  // The real school: untouched.
  assert.equal((await queryOne("SELECT name FROM subjects WHERE id = 'real-math'")).name, "Mathematics");
  assert.equal((await queryOne("SELECT name FROM institutions WHERE id = 'real-1'")).name, "Baghdad College");

  // The demo works after the reset: the student's week, in Arabic.
  const student = { Authorization: `Bearer ${(await enterAs("student")).accessToken}` };
  const week = (await request(app).get("/timetable/people/STU-2026-0142/week").set(student).expect(200)).body;
  assert.ok(week.lessons.some((l) => l.subjectName === "الرياضيات"));
});
