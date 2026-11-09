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

test("classes come with head teacher, students and subject teachers", async () => {
  const res = await request(app).get("/academics/classes").set(admin).expect(200);
  const fiveA = res.body.find((c) => c.id === "cls-5a");

  assert.equal(fiveA.homeroomTeacherName, "Huda Jaber");
  assert.ok(fiveA.studentCount >= 1); // Zainab and others
  const maths = fiveA.subjects.find((s) => s.subjectId === "math");
  assert.equal(maths.teacherName, "Ahmed Kareem");

  const fiveB = res.body.find((c) => c.id === "cls-5b");
  assert.equal(fiveB.subjects.filter((s) => s.teacherId === null).length, 2);
});

test("subjects: add, rename, delete (also from classes)", async () => {
  const added = await request(app)
    .post("/academics/subjects")
    .set(admin)
    .send({ name: "History", icon: "history", color: "orange" })
    .expect(201);

  await request(app)
    .post("/academics/subjects")
    .set(admin)
    .send({ name: "History" })
    .expect(409);

  await request(app)
    .put(`/academics/classes/cls-4a/subjects/${added.body.id}`)
    .set(admin)
    .send({ teacherId: null })
    .expect(200);

  const renamed = await request(app)
    .patch(`/academics/subjects/${added.body.id}`)
    .set(admin)
    .send({ name: "Iraqi History", icon: "history", color: "orange" })
    .expect(200);
  assert.equal(renamed.body.name, "Iraqi History");

  await request(app).delete(`/academics/subjects/${added.body.id}`).set(admin).expect(204);
  const fourA = (await request(app).get("/academics/classes/cls-4a").set(admin)).body;
  assert.ok(!fourA.subjects.some((s) => s.subjectId === added.body.id));
});

test("classes: add with subjects, head teacher, rename moves students, delete", async () => {
  const created = await request(app)
    .post("/academics/classes")
    .set(admin)
    .send({
      name: "4th Scientific – B",
      homeroomTeacherId: "TCH-2019-0045",
      subjectIds: ["math", "physics"],
    })
    .expect(201);
  assert.equal(created.body.homeroomTeacherName, "Noor Abbas");
  assert.equal(created.body.subjects.length, 2);

  // Assign a subject teacher, then remove a subject.
  const assigned = await request(app)
    .put(`/academics/classes/${created.body.id}/subjects/math`)
    .set(admin)
    .send({ teacherId: "TCH-2019-0031" })
    .expect(200);
  assert.equal(
    assigned.body.subjects.find((s) => s.subjectId === "math").teacherName,
    "Ahmed Kareem",
  );
  await request(app)
    .delete(`/academics/classes/${created.body.id}/subjects/physics`)
    .set(admin)
    .expect(200);

  // Only teachers can teach.
  await request(app)
    .put(`/academics/classes/${created.body.id}/subjects/math`)
    .set(admin)
    .send({ teacherId: "STU-2026-0142" })
    .expect(400);

  await request(app).delete(`/academics/classes/${created.body.id}`).set(admin).expect(204);

  // Renaming a class keeps its students in it.
  const renamed = await request(app)
    .patch("/academics/classes/cls-6c")
    .set(admin)
    .send({ name: "6th Scientific – C (Biology)", homeroomTeacherId: "TCH-2019-0040" })
    .expect(200);
  assert.ok(renamed.body.studentCount > 0);

  // A class with students can't be deleted.
  await request(app).delete("/academics/classes/cls-6c").set(admin).expect(409);
});

test("only administrators manage academics", async () => {
  const teacher = (await signIn(app, "TCH-2019-0031")).accessToken;
  await request(app)
    .post("/academics/subjects")
    .set("Authorization", `Bearer ${teacher}`)
    .send({ name: "Art" })
    .expect(403);
});
