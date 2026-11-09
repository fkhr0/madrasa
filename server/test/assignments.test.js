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
    ["ahmed", "TCH-2019-0031"],
    ["sara", "TCH-2019-0040"],
    ["parent", "PAR-2026-0142"],
    ["otherParent", "PAR-2026-0150"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

async function upload(who, name, text) {
  const res = await request(app)
    .post("/files")
    .set(who)
    .set("Content-Type", "text/plain")
    .set("X-File-Name", encodeURIComponent(name))
    .send(Buffer.from(text))
    .expect(201);
  return res.body;
}

/** Downloads through a short-lived link, as the phone does. */
async function download(who, fileId) {
  const { url } = (await request(app).get(`/files/${fileId}/link`).set(who).expect(200)).body;
  return request(app).get(url);
}

const inDays = (days) => new Date(Date.now() + days * 86400000).toISOString();

test("a student sees her class's homework and her own hand-ins", async () => {
  const list = (await request(app).get("/assignments/students/STU-2026-0142").set(as.zainab).expect(200)).body;
  assert.equal(list.length, 7);

  const poetry = list.find((a) => a.title === "Poetry analysis");
  assert.equal(poetry.submission.grade, 41);
  assert.equal(poetry.maxGrade, 50);
  assert.equal(poetry.subjectName, "Arabic Language");

  const worksheet = list.find((a) => a.subjectId === "math");
  assert.equal(worksheet.submission, null);

  await request(app).get("/assignments/students/STU-2026-0142").set(as.parent).expect(200);
  await request(app).get("/assignments/students/STU-2026-0142").set(as.otherParent).expect(404);
});

test("teacher sets work with a file; the student hands in hers; the teacher grades", async () => {
  const sheet = await upload(as.ahmed, "Worksheet 5.txt", "Solve x² = 4");
  assert.equal(sheet.name, "Worksheet 5.txt");

  const work = {
    subjectId: "math",
    type: "homework",
    title: "Worksheet 5",
    description: "Questions 1–5",
    dueAt: inDays(2),
    maxGrade: 10,
    fileIds: [sheet.id],
  };
  await request(app).post("/assignments/classes/cls-5a").set(as.sara).send(work).expect(403);
  // Someone else's file can't be attached.
  const notMine = await upload(as.sara, "x.txt", "x");
  await request(app)
    .post("/assignments/classes/cls-5a")
    .set(as.ahmed)
    .send({ ...work, fileIds: [notMine.id] })
    .expect(400);

  const created = (await request(app).post("/assignments/classes/cls-5a").set(as.ahmed).send(work).expect(201)).body;
  assert.equal(created.attachments[0].name, "Worksheet 5.txt");

  // The class and its parents can open the worksheet; another school's can't.
  assert.equal((await download(as.parent, sheet.id)).text, "Solve x² = 4");

  // Zainab hands in: files are required here, and must be hers.
  const url = `/assignments/${created.id}/submission`;
  await request(app).post(url).set(as.zainab).send({ fileIds: [] }).expect(400);
  await request(app).post(url).set(as.zainab).send({ fileIds: [sheet.id] }).expect(400);
  await request(app).post(url).set(as.ali).send({ fileIds: [] }).expect(403);

  const answer = await upload(as.zainab, "My answers.txt", "x = 2 or x = -2");
  const handedIn = (await request(app).post(url).set(as.zainab).send({ fileIds: [answer.id] }).expect(200)).body;
  assert.equal(handedIn.submission.files[0].name, "My answers.txt");

  // Her work: her teacher and parent can open it, a classmate can't.
  assert.equal((await download(as.ahmed, answer.id)).text, "x = 2 or x = -2");
  await request(app).get(`/files/${answer.id}/link`).set(as.parent).expect(200);
  await request(app).get(`/files/${answer.id}/link`).set(as.fatima).expect(404);

  // The teacher sees who handed in, and grades.
  const subs = (await request(app).get(`/assignments/${created.id}/submissions`).set(as.ahmed).expect(200)).body;
  assert.ok(subs.students.find((s) => s.id === "STU-2026-0142").submission.submittedAt);

  const gradeUrl = `/assignments/${created.id}/submissions/STU-2026-0142/grade`;
  await request(app).put(gradeUrl).set(as.ahmed).send({ grade: 11 }).expect(400);
  await request(app).put(gradeUrl).set(as.ahmed).send({ grade: 9, feedback: "Well done" }).expect(200);

  const mine = (await request(app).get("/assignments/students/STU-2026-0142").set(as.zainab)).body;
  const graded = mine.find((a) => a.id === created.id);
  assert.equal(graded.submission.grade, 9);
  assert.equal(graded.submission.feedback, "Well done");

  // Graded work can't be handed in again.
  await request(app).post(url).set(as.zainab).send({ fileIds: [answer.id] }).expect(409);

  const told = (await request(app).get("/notifications").set(as.parent)).body;
  const items = Array.isArray(told) ? told : told.items;
  assert.ok(items.some((n) => n.title === "New Mathematics homework"));
  assert.ok(items.some((n) => n.title === "Mathematics: 9 / 10"));
});

test("late work only when the teacher allows it", async () => {
  const late = (
    await request(app)
      .post("/assignments/classes/cls-5a")
      .set(as.ahmed)
      .send({ subjectId: "math", type: "homework", title: "Old work", dueAt: inDays(-1), acceptsFiles: false })
      .expect(201)
  ).body;
  await request(app).post(`/assignments/${late.id}/submission`).set(as.zainab).send({}).expect(400);

  await request(app)
    .patch(`/assignments/${late.id}`)
    .set(as.ahmed)
    .send({ subjectId: "math", type: "homework", title: "Old work", dueAt: inDays(-1), acceptsFiles: false, allowsLate: true })
    .expect(200);
  await request(app).post(`/assignments/${late.id}/submission`).set(as.zainab).send({}).expect(200);

  // The office can manage any subject; the teacher deletes his own.
  const all = (await request(app).get("/assignments/classes/cls-5a").set(as.admin).expect(200)).body;
  assert.ok(all.some((a) => a.subjectId !== "math"));
  const his = (await request(app).get("/assignments/classes/cls-5a").set(as.ahmed).expect(200)).body;
  assert.ok(his.every((a) => a.subjectId === "math"));

  await request(app).delete(`/assignments/${late.id}`).set(as.sara).expect(403);
  await request(app).delete(`/assignments/${late.id}`).set(as.ahmed).expect(204);
});

test("a download link only works with its token", async () => {
  const file = await upload(as.zainab, "notes.txt", "hello");
  await request(app).get(`/files/${file.id}/download?t=nope`).expect(401);
  await request(app).post("/files").set(as.zainab).send(Buffer.alloc(0)).expect(400);
});
