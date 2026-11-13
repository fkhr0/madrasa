const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [
    ["admin", "ADM-2020-0001"],
    ["zainab", "STU-2026-0142"],
    ["fatima", "STU-2026-0150"],
    ["ali", "STU-2026-0153"], // 5th B
    ["otherSchool", "STU-2026-0388"], // the intermediate school
    ["ahmed", "TCH-2019-0031"],
    ["sara", "TCH-2019-0040"],
    ["parent", "PAR-2026-0142"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

test("tasks are private: add, tick, delete", async () => {
  const mine = (await request(app).get("/tasks").set(as.zainab).expect(200)).body;
  assert.equal(mine.length, 6);
  assert.equal((await request(app).get("/tasks").set(as.fatima)).body.length, 0);

  const task = { id: "x1", title: "Revise maths", dueAt: new Date().toISOString(), priority: "high" };
  await request(app).post("/tasks").set(as.fatima).send(task).expect(201);
  await request(app).post("/tasks").set(as.fatima).send(task).expect(409);
  // The same ID is fine for someone else.
  await request(app).post("/tasks").set(as.zainab).send(task).expect(201);

  const done = (await request(app).patch("/tasks/x1").set(as.fatima).send({ isDone: true }).expect(200)).body;
  assert.equal(done.isDone, true);
  await request(app).delete("/tasks/x1").set(as.fatima).expect(204);
  await request(app).delete("/tasks/x1").set(as.fatima).expect(404);
  assert.ok((await request(app).get("/tasks").set(as.zainab)).body.some((t) => t.id === "x1"));
});

test("study material: the teacher shares, the class sees it", async () => {
  const seen = (await request(app).get("/resources/students/STU-2026-0142").set(as.parent).expect(200)).body;
  assert.ok(seen.some((r) => r.title === "Forces simulation (PhET)" && r.url.startsWith("https://")));

  const file = (
    await request(app)
      .post("/files")
      .set(as.ahmed)
      .set("Content-Type", "application/pdf")
      .set("X-File-Name", "Chapter 3.pdf")
      .send(Buffer.from("%PDF-1.4 demo"))
      .expect(201)
  ).body;

  const shared = { subjectId: "math", title: "Chapter 3 summary", type: "pdf", fileId: file.id };
  await request(app).post("/resources/classes/cls-5a").set(as.sara).send(shared).expect(403);
  await request(app).post("/resources/classes/cls-5a").set(as.ahmed).send({ ...shared, fileId: null }).expect(400);
  await request(app)
    .post("/resources/classes/cls-5a")
    .set(as.ahmed)
    .send({ ...shared, url: "javascript:alert(1)", fileId: null })
    .expect(400);

  const created = (await request(app).post("/resources/classes/cls-5a").set(as.ahmed).send(shared).expect(201)).body;
  assert.equal(created.fileName, "Chapter 3.pdf");

  // Zainab can open the file; a student of another school can't.
  await request(app).get(`/files/${file.id}/link`).set(as.zainab).expect(200);
  await request(app).get(`/files/${file.id}/link`).set(as.otherSchool).expect(404);
  assert.equal((await request(app).get("/resources/students/STU-2026-0153").set(as.ali)).body.length, 0);

  const his = (await request(app).get("/resources/classes/cls-5a").set(as.ahmed).expect(200)).body;
  assert.ok(his.every((r) => r.subjectId === "math"));

  await request(app).delete(`/resources/${created.id}`).set(as.sara).expect(403);
  await request(app).delete(`/resources/${created.id}`).set(as.admin).expect(204);
});
