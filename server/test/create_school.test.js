// The command that makes a real school: its admin, or one account per role.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const { createSchool } = require("../src/db/create-school");

let app, made;
before(async () => {
  app = await startTestApp();
  made = await createSchool("مدرسة التجربة", { sample: true });
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

test("normally only the school and its admin: the office adds the rest", async () => {
  const school = await createSchool("مدرسة الرافدين", { adminName: "علي حسن" });
  assert.deepEqual(school.people.map((p) => [p.role, p.name]), [["admin", "علي حسن"]]);
  const [admin] = school.people;
  const as = { Authorization: `Bearer ${(await signIn(app, admin.id, admin.password)).accessToken}` };
  assert.deepEqual((await request(app).get("/academics/classes").set(as).expect(200)).body, []);
  assert.deepEqual((await request(app).get("/people?role=student").set(as).expect(200)).body, []);
});

test("a new school has no fees until the office sets them: nothing is late", async () => {
  const [admin, , student, parent] = made.people;
  const asParent = { Authorization: `Bearer ${(await signIn(app, parent.id, parent.password)).accessToken}` };
  const before = (await request(app).get(`/finance/accounts/${student.id}`).set(asParent).expect(200)).body;
  assert.equal(before.feesSet, false);
  assert.equal(before.tuition, 0);
  assert.equal(before.busFee, 0);

  const asAdmin = { Authorization: `Bearer ${(await signIn(app, admin.id, admin.password)).accessToken}` };
  // With no dates saved, the first one offered is the start of the study year.
  const { dueDates } = (await request(app).get("/finance/settings").set(asAdmin).expect(200)).body;
  await request(app)
    .put("/finance/settings")
    .set(asAdmin)
    .send({ tuition: 1500000, busFee: 0, dueDates, classTuition: {} })
    .expect(200);
  const after = (await request(app).get(`/finance/accounts/${student.id}`).set(asParent).expect(200)).body;
  assert.equal(after.feesSet, true);
  assert.equal(after.tuition, 1500000);
});
