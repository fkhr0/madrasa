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
    ["omar", "TCH-2019-0041"],
    ["parent", "PAR-2026-0142"],
  ]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const ids = (list) => list.map((x) => x.id);

test("who may message whom", async () => {
  const zainab = ids((await request(app).get("/messages/contacts").set(as.zainab).expect(200)).body);
  assert.ok(zainab.includes("TCH-2019-0031")); // her maths teacher
  assert.ok(zainab.includes("ADM-2020-0001")); // the office
  assert.ok(!zainab.includes("STU-2026-0150")); // not other students

  const parent = ids((await request(app).get("/messages/contacts").set(as.parent).expect(200)).body);
  assert.ok(parent.includes("TCH-2019-0042")); // Zainab's Arabic teacher
  assert.ok(!parent.includes("PAR-2026-0150"));

  const ahmed = ids((await request(app).get("/messages/contacts").set(as.ahmed).expect(200)).body);
  assert.ok(ahmed.includes("TCH-2019-0041")); // a colleague
  assert.ok(ahmed.includes("STU-2026-0142")); // his student
  assert.ok(ahmed.includes("PAR-2026-0142")); // his student's parent

  const admin = ids((await request(app).get("/messages/contacts").set(as.admin).expect(200)).body);
  assert.ok(admin.includes("STU-2026-0153"));

  await request(app).post("/messages/conversations").set(as.zainab).send({ userId: "STU-2026-0150" }).expect(403);
});

test("a private chat: the same one each time, unread counts, read on open", async () => {
  const { id } = (await request(app).post("/messages/conversations").set(as.parent).send({ userId: "TCH-2019-0031" }).expect(200)).body;
  const again = (await request(app).post("/messages/conversations").set(as.parent).send({ userId: "TCH-2019-0031" }).expect(200)).body;
  assert.equal(again.id, id);

  await request(app).post(`/messages/conversations/${id}/messages`).set(as.parent).send({ text: "  " }).expect(400);
  const sent = (await request(app).post(`/messages/conversations/${id}/messages`).set(as.parent).send({ text: "Hello, Mr. Ahmed" }).expect(201)).body;
  assert.equal(sent.isMine, true);

  const before = (await request(app).get("/messages/conversations").set(as.ahmed)).body.find((c) => c.id === id);
  assert.equal(before.unreadCount, 1);
  assert.equal(before.title, "Haider Jasim");
  assert.equal(before.subtitle, "Parent");
  assert.equal(before.lastMessage, "Hello, Mr. Ahmed");

  const read = (await request(app).get(`/messages/conversations/${id}/messages`).set(as.ahmed).expect(200)).body;
  assert.equal(read.at(-1).text, "Hello, Mr. Ahmed");
  assert.equal(read.at(-1).isMine, false);
  const after = (await request(app).get("/messages/conversations").set(as.ahmed)).body.find((c) => c.id === id);
  assert.equal(after.unreadCount, 0);

  // Only newer messages with ?after=.
  const none = (await request(app).get(`/messages/conversations/${id}/messages?after=${encodeURIComponent(sent.sentAt)}`).set(as.ahmed)).body;
  assert.equal(none.length, 0);

  // Others can't read it.
  await request(app).get(`/messages/conversations/${id}/messages`).set(as.zainab).expect(404);
});

test("the class chat belongs to its students and teachers", async () => {
  const fiveA = (await request(app).get("/messages/conversations").set(as.zainab)).body.find((c) => c.isGroup);
  assert.equal(fiveA.title, "5th Scientific – A");
  assert.ok(fiveA.lastMessage.length > 0);

  const omars = (await request(app).get("/messages/conversations").set(as.omar)).body;
  assert.ok(omars.some((c) => c.id === fiveA.id));

  await request(app).post(`/messages/conversations/${fiveA.id}/messages`).set(as.fatima).send({ text: "Thanks!" }).expect(201);
  await request(app).get(`/messages/conversations/${fiveA.id}/messages`).set(as.ali).expect(404);
  await request(app).post(`/messages/conversations/${fiveA.id}/messages`).set(as.parent).send({ text: "Hi" }).expect(404);
});

test("seen ticks, editing and deleting your own messages", async () => {
  const { id } = (await request(app).post("/messages/conversations").set(as.parent).send({ userId: "TCH-2019-0031" })).body;
  const sent = (await request(app).post(`/messages/conversations/${id}/messages`).set(as.parent).send({ text: "Is the exam on Sunday?" }).expect(201)).body;
  const mine = async () =>
    (await request(app).get(`/messages/conversations/${id}/messages`).set(as.parent)).body.find((m) => m.id === sent.id);

  // Not seen until the teacher opens the chat.
  assert.equal((await mine()).seen, false);
  await request(app).get(`/messages/conversations/${id}/messages`).set(as.ahmed).expect(200);
  assert.equal((await mine()).seen, true);

  // Only the writer edits; it says "edited".
  await request(app).patch(`/messages/conversations/${id}/messages/${sent.id}`).set(as.ahmed).send({ text: "x" }).expect(404);
  await request(app).patch(`/messages/conversations/${id}/messages/${sent.id}`).set(as.parent).send({ text: "Is the exam on Monday?" }).expect(200);
  assert.equal((await mine()).text, "Is the exam on Monday?");
  assert.equal((await mine()).edited, true);

  // Deleted for everyone: the text is gone, the place stays.
  await request(app).delete(`/messages/conversations/${id}/messages/${sent.id}`).set(as.parent).expect(204);
  const gone = await mine();
  assert.equal(gone.deleted, true);
  assert.equal(gone.text, "");
  const list = (await request(app).get("/messages/conversations").set(as.ahmed)).body.find((c) => c.id === id);
  assert.equal(list.lastMessage, "This message was deleted");
  await request(app).delete(`/messages/conversations/${id}/messages/${sent.id}`).set(as.parent).expect(404);
});
