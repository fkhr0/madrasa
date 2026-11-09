const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
before(async () => (app = await startTestApp()));
after(close);

test("signs in with the school ID (any letter case)", async () => {
  const { accessToken, refreshToken, user } = await signIn(app, "stu-2026-0142");

  assert.ok(accessToken);
  assert.ok(refreshToken);
  assert.equal(user.name, "Zainab Haider");
  assert.equal(user.role, "student");
  assert.equal(user.schoolName, "Al-Noor Preparatory School");
  assert.equal(user.password_hash, undefined);
});

test("a wrong password and an unknown ID get the same answer", async () => {
  const wrong = await request(app)
    .post("/auth/login")
    .send({ schoolId: "STU-2026-0142", password: "nope" })
    .expect(401);
  const unknown = await request(app)
    .post("/auth/login")
    .send({ schoolId: "STU-1999-9999", password: "nope" })
    .expect(401);

  assert.equal(wrong.body.error, unknown.body.error);
});

test("a parent gets their children, from both schools", async () => {
  const { user } = await signIn(app, "PAR-2026-0142");

  assert.deepEqual(
    user.children.map((c) => [c.name, c.schoolName]),
    [
      ["Ali Haider", "Al-Noor Intermediate School"],
      ["Zainab Haider", "Al-Noor Preparatory School"],
    ],
  );
});

test("the access token opens /me; no token is refused", async () => {
  const { accessToken } = await signIn(app, "TCH-2019-0031");

  const me = await request(app)
    .get("/me")
    .set("Authorization", `Bearer ${accessToken}`)
    .expect(200);
  assert.equal(me.body.subjectName, "Mathematics");

  await request(app).get("/me").expect(401);
  await request(app)
    .get("/me")
    .set("Authorization", "Bearer forged.token.here")
    .expect(401);
});

test("refresh tokens rotate and can't be used twice", async () => {
  const { refreshToken } = await signIn(app, "ADM-2020-0001");

  const first = await request(app)
    .post("/auth/refresh")
    .send({ refreshToken })
    .expect(200);
  assert.notEqual(first.body.refreshToken, refreshToken);

  // The old one is spent.
  await request(app).post("/auth/refresh").send({ refreshToken }).expect(401);

  // Sign out: the new one stops working too.
  await request(app)
    .post("/auth/logout")
    .send({ refreshToken: first.body.refreshToken })
    .expect(204);
  await request(app)
    .post("/auth/refresh")
    .send({ refreshToken: first.body.refreshToken })
    .expect(401);
});

test("contact info and password changes", async () => {
  const { accessToken, refreshToken } = await signIn(app, "DRV-2024-0012");
  const auth = { Authorization: `Bearer ${accessToken}` };

  const updated = await request(app)
    .patch("/me")
    .set(auth)
    .send({ email: "kadhim@example.com", phone: "+964 770 900 1212" })
    .expect(200);
  assert.equal(updated.body.email, "kadhim@example.com");

  await request(app)
    .patch("/me")
    .set(auth)
    .send({ email: "not-an-email", phone: "" })
    .expect(400);

  await request(app)
    .post("/me/password")
    .set(auth)
    .send({ currentPassword: "wrong", newPassword: "a-new-password" })
    .expect(400);
  await request(app)
    .post("/me/password")
    .set(auth)
    .send({ currentPassword: "demo1234", newPassword: "short" })
    .expect(400);
  await request(app)
    .post("/me/password")
    .set(auth)
    .send({
      currentPassword: "demo1234",
      newPassword: "a-new-password",
      refreshToken,
    })
    .expect(204);

  await signIn(app, "DRV-2024-0012", "a-new-password");
  await request(app)
    .post("/auth/login")
    .send({ schoolId: "DRV-2024-0012", password: "demo1234" })
    .expect(401);
});

test("password reset never reveals whether an account exists", async () => {
  await request(app)
    .post("/auth/password-reset")
    .send({ emailOrPhone: "nobody@nowhere.iq" })
    .expect(202);
});
