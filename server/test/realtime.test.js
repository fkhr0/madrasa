const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const WebSocket = require("ws");
const { startTestApp, signIn, close, request } = require("./helpers");
const hub = require("../src/realtime/hub");

let app;
let server;
let url;
const tokens = {};
before(async () => {
  app = await startTestApp();
  server = app.listen(0);
  hub.attach(server);
  url = `ws://127.0.0.1:${server.address().port}/ws`;
  for (const id of ["PAR-2026-0142", "TCH-2019-0031", "STU-2026-0150"]) {
    tokens[id] = (await signIn(app, id)).accessToken;
  }
});
after(async () => {
  server.close();
  await close();
});

/** A signed-in socket and the events it receives. */
function connect(token) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    const events = [];
    socket.on("open", () => socket.send(JSON.stringify({ type: "auth", token })));
    socket.on("message", (data) => {
      const event = JSON.parse(String(data));
      if (event.type === "ready") resolve({ socket, events });
      else events.push(event);
    });
    socket.on("close", (code) => reject(new Error(`closed ${code}`)));
    socket.on("error", reject);
  });
}

const until = async (check) => {
  for (let i = 0; i < 50 && !check(); i++) await new Promise((r) => setTimeout(r, 20));
  return check();
};

test("a bad token is refused", async () => {
  const code = await new Promise((resolve) => {
    const socket = new WebSocket(url);
    socket.on("open", () => socket.send(JSON.stringify({ type: "auth", token: "nope" })));
    socket.on("close", (c) => resolve(c));
  });
  assert.equal(code, 4001);
});

test("a page from another website can't connect", async () => {
  const status = await new Promise((resolve) => {
    const socket = new WebSocket(url, { origin: "https://evil.example" });
    socket.on("unexpected-response", (_req, res) => resolve(res.statusCode));
    socket.on("open", () => resolve("open"));
    socket.on("error", () => {});
  });
  assert.equal(status, 401);
});

test("a chat message reaches the other person at once, and a notification too", async () => {
  const teacher = await connect(tokens["TCH-2019-0031"]);
  const stranger = await connect(tokens["STU-2026-0150"]);
  const parent = { Authorization: `Bearer ${tokens["PAR-2026-0142"]}` };

  const { id } = (await request(app).post("/messages/conversations").set(parent).send({ userId: "TCH-2019-0031" })).body;
  await request(app).post(`/messages/conversations/${id}/messages`).set(parent).send({ text: "Hi" }).expect(201);

  assert.ok(await until(() => teacher.events.some((e) => e.type === "message.new" && e.conversationId === id)));
  assert.ok(!stranger.events.some((e) => e.type === "message.new"));

  // A homework from the teacher notifies Fatima's class at once.
  const teacherAuth = { Authorization: `Bearer ${tokens["TCH-2019-0031"]}` };
  await request(app)
    .post("/assignments/classes/cls-5a")
    .set(teacherAuth)
    .send({ subjectId: "math", type: "homework", title: "Live test", dueAt: new Date(Date.now() + 86400000).toISOString(), acceptsFiles: false })
    .expect(201);
  assert.ok(await until(() => stranger.events.some((e) => e.type === "notification.new")));

  teacher.socket.close();
  stranger.socket.close();
});

test("one person can't keep more than 5 live connections", async () => {
  const token = tokens["STU-2026-0150"];
  const open = [];
  for (let i = 0; i < 6; i++) open.push(await connect(token));
  const closed = await new Promise((resolve) => {
    open[0].socket.on("close", (code) => resolve(code));
    setTimeout(() => resolve(null), 1000);
  });
  assert.equal(closed, 4008);
  for (const { socket } of open) socket.close();
});
