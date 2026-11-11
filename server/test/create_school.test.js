// The command that makes a real school with one account per role.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { createSchool } = require("../src/db/create-school");

let app, made;
before(async () => {
  app = await startTestApp();
  made = await createSchool("مدرسة التجربة");
});
after(close);

test("every account signs in and must choose a new password", async () => {
  assert.deepEqual(made.people.map((p) => p.role), ["admin", "teacher", "student", "parent", "driver"]);
  for (const p of made.people) {
    const session = await signIn(app, p.id, p.password);
    assert.equal(session.user.mustChangePassword, true, p.role);
  }
});

test("the school is ready to use: class, subject, teacher, child", async () => {
  const [admin, teacher, student, parent] = made.people;
  const as = { Authorization: `Bearer ${(await signIn(app, admin.id, admin.password)).accessToken}` };

  const classes = (await request(app).get("/academics/classes").set(as).expect(200)).body;
  assert.equal(classes.length, 1);
  assert.equal(classes[0].name, student.className);

  const kid = (await request(app).get(`/people/${parent.id}`).set(as).expect(200)).body;
  assert.deepEqual(kid.childIds ?? kid.children.map((c) => c.id), [student.id]);

  // Only its own people: none of the demo school's.
  const teachers = (await request(app).get("/people?role=teacher").set(as).expect(200)).body;
  assert.deepEqual(teachers.map((t) => t.id), [teacher.id]);
});

test("the same name twice is refused", async () => {
  await assert.rejects(createSchool("مدرسة التجربة"), /exists already/);
});
