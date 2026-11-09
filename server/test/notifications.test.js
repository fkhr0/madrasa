const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [role, id] of [
    ["admin", "ADM-2020-0001"],
    ["student", "STU-2026-0142"], // rides bus 12 from Al-Yarmouk (s4)
    ["parent", "PAR-2026-0142"],
    ["teacher", "TCH-2019-0031"],
    ["driver", "DRV-2024-0012"],
  ]) {
    as[role] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const titles = async (who) =>
  (await request(app).get("/notifications").set(who).expect(200)).body.map((n) => n.title);

const trip = (path, body = {}) =>
  request(app).post(`/transport/routes/route-1/trip/${path}`).set(as.driver).send(body).expect(path === "start" ? 201 : 200);

test("bus trips tell the families, the driver and the office", async () => {
  await trip("start", { direction: "toSchool" });
  assert.ok((await titles(as.parent)).includes("Bus 12 started the morning trip"));
  assert.ok((await titles(as.admin)).includes("Bus 12 started the morning trip"));

  // Close to Al-Yarmouk (Zainab's stop), driving there from Hay Al-Jamia.
  await trip("location", { latitude: 33.3381, longitude: 44.2701 }); // s1
  await trip("location", { latitude: 33.33, longitude: 44.29 }); // left s1
  await trip("location", { latitude: 33.3301, longitude: 44.3001 }); // s2
  await trip("location", { latitude: 33.32, longitude: 44.31 }); // left s2
  await trip("location", { latitude: 33.3171, longitude: 44.3181 }); // s3
  await trip("location", { latitude: 33.31, longitude: 44.325 }); // left s3, ~1.5 km from s4
  const near = await titles(as.parent);
  assert.ok(near.some((t) => /^Bus 12 is about \d min away$/.test(t)), near.join(" | "));

  // Told once, not on every GPS point.
  await trip("location", { latitude: 33.305, longitude: 44.33 });
  const count = (await titles(as.parent)).filter((t) => t.includes("min away")).length;
  assert.equal(count, 1);

  await trip("location", { latitude: 33.3001, longitude: 44.3351 }); // at s4
  assert.ok((await titles(as.student)).includes("Bus 12 is at Al-Yarmouk"));

  await trip("boarding", { studentId: "STU-2026-0142", status: "onBoard" });
  assert.ok((await titles(as.parent)).includes("Zainab Haider is on bus 12"));

  await trip("delay", { minutes: 10, reason: "Traffic" });
  assert.ok((await titles(as.parent)).includes("Bus 12 is running 10 min late"));

  await trip("end", { earlyReason: "Flat tyre" });
  assert.ok((await titles(as.admin)).includes("Bus 12 ended the morning trip early"));
});

test("a parent's 'won't ride today' reaches the driver", async () => {
  await request(app)
    .post("/transport/students/STU-2026-0142/not-riding")
    .set(as.parent)
    .send({ notRiding: true })
    .expect(204);
  assert.ok((await titles(as.driver)).includes("Zainab Haider won't ride today"));
  // Drivers only hear about their bus.
  assert.ok((await titles(as.driver)).every((t) => !t.startsWith("New event")));
});

test("announcements and events reach the people they are for", async () => {
  await request(app)
    .post("/announcements")
    .set(as.teacher)
    .send({ title: "Quiz on Sunday", body: "Chapter 4.", audience: "class", className: "5th Scientific – A" })
    .expect(201);
  assert.ok((await titles(as.student)).includes("Quiz on Sunday"));
  assert.ok((await titles(as.parent)).includes("Quiz on Sunday"));
  assert.ok(!(await titles(as.teacher)).includes("Quiz on Sunday")); // its author
  assert.ok(!(await titles(as.driver)).includes("Quiz on Sunday"));

  // Scheduled: nobody is told until its time.
  await request(app)
    .post("/announcements")
    .set(as.admin)
    .send({
      title: "Winter uniform",
      body: "From Sunday.",
      audience: "school",
      publishedAt: new Date(Date.now() + 3600_000).toISOString(),
    })
    .expect(201);
  assert.ok(!(await titles(as.student)).includes("Winter uniform"));

  await request(app)
    .post("/events")
    .set(as.admin)
    .send({ title: "Open day", type: "event", audience: "everyone", date: "2026-12-03", time: "09:00" })
    .expect(201);
  assert.ok((await titles(as.parent)).includes("New event: Open day"));
});

test("marking read", async () => {
  const [first] = (await request(app).get("/notifications").set(as.parent)).body;
  assert.equal(first.isRead, false);
  await request(app).post(`/notifications/${first.id}/read`).set(as.parent).expect(204);
  await request(app).post("/notifications/read-all").set(as.parent).expect(204);
  const all = (await request(app).get("/notifications").set(as.parent)).body;
  assert.ok(all.every((n) => n.isRead));
  // Someone else's: nothing happens.
  const mine = (await request(app).get("/notifications").set(as.student)).body;
  await request(app).post(`/notifications/${mine[0].id}/read`).set(as.parent).expect(204);
  const still = (await request(app).get("/notifications").set(as.student)).body;
  assert.equal(still.find((n) => n.id === mine[0].id).isRead, false);
});

test("a phone turns on push notifications", async () => {
  const key = await request(app).get("/notifications/push-key").set(as.parent).expect(200);
  assert.ok(key.body.publicKey.length > 40);

  const sub = {
    endpoint: "https://push.example.test/abc",
    keys: { p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM", auth: "tBHItJI5svbpez7KI4CCXg" },
  };
  await request(app).post("/notifications/push").set(as.parent).send(sub).expect(204);
  await request(app).post("/notifications/push").set(as.parent).send({ endpoint: "nope" }).expect(400);
  await request(app).delete("/notifications/push").set(as.parent).send({ endpoint: sub.endpoint }).expect(204);
});

test("Android phones get notifications through Firebase; dead tokens are forgotten", async () => {
  const fcm = require("../src/features/notifications/fcm");
  const { query } = require("../src/db/database");
  const sent = [];
  fcm.useMessaging({
    async sendEachForMulticast(message) {
      sent.push(message);
      // The student's app was uninstalled.
      return {
        responses: message.fids.map((t) =>
          t.startsWith("student") ? { error: { code: "messaging/registration-token-not-registered" } } : {},
        ),
      };
    },
  });
  const parentPhone = `parent-phone-${"x".repeat(30)}`;
  const studentPhone = `student-phone-${"x".repeat(30)}`;
  await request(app).post("/notifications/devices").set(as.parent).send({ token: parentPhone, platform: "android" }).expect(204);
  await request(app).post("/notifications/devices").set(as.student).send({ token: studentPhone, platform: "android" }).expect(204);
  await request(app).post("/notifications/devices").set(as.student).send({ token: "short", platform: "android" }).expect(400);

  await request(app)
    .post("/announcements")
    .set(as.teacher)
    .send({ title: "Trip on Monday", body: "Bring water.", audience: "class", className: "5th Scientific – A" })
    .expect(201);
  for (let i = 0; i < 50 && sent.length === 0; i++) await new Promise((r) => setTimeout(r, 20));

  const tokens = sent.flatMap((m) => m.fids);
  assert.ok(tokens.includes(parentPhone) && tokens.includes(studentPhone));
  assert.equal(sent[0].notification.title, "Trip on Monday");
  assert.equal(sent[0].android.notification.channelId, "school");
  assert.deepEqual(await query("SELECT token FROM device_tokens"), [{ token: parentPhone }]);

  // Signed out on that phone.
  await request(app).delete("/notifications/devices").set(as.parent).send({ token: parentPhone }).expect(204);
  assert.deepEqual(await query("SELECT token FROM device_tokens"), []);
  fcm.useMessaging(null);
});
