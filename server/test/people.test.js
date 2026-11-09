const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
let admin;
before(async () => {
  app = await startTestApp();
  admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };
});
after(close);

const year = new Date().getFullYear();

test("only administrators see People", async () => {
  const teacher = (await signIn(app, "TCH-2019-0031")).accessToken;
  await request(app)
    .get("/people?role=student")
    .set("Authorization", `Bearer ${teacher}`)
    .expect(403);
});

test("lists one role of the admin's own school", async () => {
  const res = await request(app).get("/people?role=student").set(admin).expect(200);
  const ids = res.body.map((u) => u.id);

  assert.ok(ids.includes("STU-2026-0142"));
  // Ali is in the intermediate school: not this admin's student.
  assert.ok(!ids.includes("STU-2026-0388"));
  assert.ok(res.body.some((u) => u.isActive === false));
});

test("creating an account generates the ID and a temporary password", async () => {
  const first = await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "student", name: "Mina Kamal", className: "4th Scientific – A" })
    .expect(201);
  const second = await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "student", name: "Hassan Ali", className: "4th Scientific – A" })
    .expect(201);

  const n = (id) => Number(id.split("-")[2]);
  assert.ok(first.body.user.id.startsWith(`STU-${year}-`));
  assert.match(first.body.user.id, /^STU-\d{4}-\d{4}$/);
  assert.equal(n(second.body.user.id), n(first.body.user.id) + 1);
  assert.equal(first.body.temporaryPassword.length, 8);
  assert.equal(first.body.user.mustChangePassword, true);

  // The new student can sign in with the temporary password.
  await signIn(app, first.body.user.id, first.body.temporaryPassword);
});

test("each role's required fields are checked", async () => {
  await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "student", name: "No Class" })
    .expect(400);
  await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "driver", name: "No Phone" })
    .expect(400);
  await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "parent", name: "Wrong Child", childIds: ["STU-2026-0388"] })
    .expect(400);
  await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "teacher", name: "Mononym", subjectName: "Physics" })
    .expect(400);
});

test("a parent is created with children and edited", async () => {
  const created = await request(app)
    .post("/people")
    .set(admin)
    .send({ role: "parent", name: "Umm Fatima", phone: "+964 770 1", childIds: ["STU-2026-0150"] })
    .expect(201);
  assert.deepEqual(created.body.user.children.map((c) => c.id), ["STU-2026-0150"]);

  const edited = await request(app)
    .patch(`/people/${created.body.user.id}`)
    .set(admin)
    .send({
      name: "Umm Fatima Ali",
      phone: "+964 770 2",
      childIds: ["STU-2026-0150", "STU-2026-0151"],
    })
    .expect(200);
  assert.equal(edited.body.name, "Umm Fatima Ali");
  assert.equal(edited.body.children.length, 2);
});

test("deactivate, reset password, delete", async () => {
  const { refreshToken } = await signIn(app, "TCH-2019-0040");

  await request(app)
    .post("/people/TCH-2019-0040/active")
    .set(admin)
    .send({ isActive: false })
    .expect(200);
  // Signed out everywhere, and can't sign in.
  await request(app).post("/auth/refresh").send({ refreshToken }).expect(401);
  await request(app)
    .post("/auth/login")
    .send({ schoolId: "TCH-2019-0040", password: "demo1234" })
    .expect(403);

  await request(app)
    .post("/people/TCH-2019-0040/active")
    .set(admin)
    .send({ isActive: true })
    .expect(200);
  const reset = await request(app)
    .post("/people/TCH-2019-0040/reset-password")
    .set(admin)
    .expect(200);
  await signIn(app, "TCH-2019-0040", reset.body.temporaryPassword);

  await request(app).delete("/people/TCH-2019-0040").set(admin).expect(204);
  await request(app).get("/people/TCH-2019-0040").set(admin).expect(404);

  // Not yourself.
  await request(app).delete("/people/ADM-2020-0001").set(admin).expect(400);
});
