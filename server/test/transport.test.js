const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [role, id] of [
    ["admin", "ADM-2020-0001"],
    ["student", "STU-2026-0142"],
    ["parent", "PAR-2026-0142"],
    ["driver", "DRV-2024-0012"], // Al-Mansour line
    ["otherDriver", "DRV-2024-0019"],
  ]) {
    as[role] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

test("a student sees their bus, ending at the school's location", async () => {
  const res = await request(app)
    .get("/transport/students/STU-2026-0142")
    .set(as.parent)
    .expect(200);
  assert.equal(res.body.route.name, "Al-Mansour line");
  assert.equal(res.body.stopId, "s4");
  const school = res.body.route.stops.at(-1);
  assert.equal(school.id, "school");
  assert.equal(school.latitude, 33.315);

  // Moving the school moves the end of every line.
  const settings = (await request(app).get("/institution").set(as.admin)).body;
  await request(app)
    .patch("/institution")
    .set(as.admin)
    .send({ ...settings, latitude: 33.32, longitude: 44.37 })
    .expect(200);
  const line = await request(app).get("/transport/routes/route-1").set(as.student);
  assert.equal(line.body.stops.at(-1).latitude, 33.32);

  await request(app).get("/transport/students/STU-2026-0150").set(as.parent).expect(403);
});

test("a parent says the child won't ride today; the driver sees it", async () => {
  await request(app)
    .post("/transport/students/STU-2026-0142/not-riding")
    .set(as.parent)
    .send({ notRiding: true })
    .expect(204);
  const riders = await request(app)
    .get("/transport/routes/route-1/students")
    .set(as.driver)
    .expect(200);
  const zainab = riders.body.find((r) => r.id === "STU-2026-0142");
  assert.equal(zainab.notRidingToday, true);
  assert.equal(zainab.parentName, "Haider Jasim");
  // Sorted by stop, from the first pick-up.
  assert.equal(riders.body[0].stopId, "s1");
});

test("an administrator manages lines, stops and riders", async () => {
  const created = await request(app)
    .post("/transport/routes")
    .set(as.admin)
    .send({
      name: "Al-Adhamiya line",
      busNumber: "3",
      capacity: 1,
      driverId: "DRV-2024-0012", // moves the driver off the Al-Mansour line
      stops: [
        { name: "Antar square", latitude: 33.37, longitude: 44.36, morningMinute: 420, afternoonMinute: 840 },
        { id: "school", name: "School", latitude: 0, longitude: 0, morningMinute: 470, afternoonMinute: 805 },
      ],
    })
    .expect(201);
  assert.equal(created.body.stops.length, 2);
  assert.equal(created.body.stops[1].morningMinute, 470);
  const old = await request(app).get("/transport/routes/route-1").set(as.admin);
  assert.equal(old.body.driverId, "");

  const stopId = created.body.stops[0].id;
  const put = (student) =>
    request(app)
      .put(`/transport/routes/${created.body.id}/students/${student}`)
      .set(as.admin)
      .send({ stopId });
  await put("STU-2026-0163").expect(204);
  await put("STU-2026-0164").expect(409); // one seat

  // Renaming the stop keeps its rider; removing it takes them off.
  const renamed = await request(app)
    .patch(`/transport/routes/${created.body.id}`)
    .set(as.admin)
    .send({ ...created.body, stops: [{ ...created.body.stops[0], name: "Antar" }, created.body.stops[1]] })
    .expect(200);
  assert.equal(renamed.body.studentCount, 1);
  const emptied = await request(app)
    .patch(`/transport/routes/${created.body.id}`)
    .set(as.admin)
    .send({ ...created.body, stops: [created.body.stops[1]] })
    .expect(200);
  assert.equal(emptied.body.studentCount, 0);

  await request(app).delete(`/transport/routes/${created.body.id}`).set(as.admin).expect(204);
  // Give the driver back their line.
  await request(app)
    .patch("/transport/routes/route-1")
    .set(as.admin)
    .send({ ...old.body, driverId: "DRV-2024-0012" })
    .expect(200);
});

test("the driver runs a trip; GPS moves the bus", async () => {
  // Another line's driver can't start this bus.
  await request(app)
    .post("/transport/routes/route-1/trip/start")
    .set(as.otherDriver)
    .send({ direction: "toSchool" })
    .expect(403);

  const started = await request(app)
    .post("/transport/routes/route-1/trip/start")
    .set(as.driver)
    .send({ direction: "toSchool" })
    .expect(201);
  assert.deepEqual(started.body.stopIds.slice(0, 2), ["s1", "s2"]);
  // The bus starts where the driver is, on its way to the first stop.
  assert.equal(started.body.reachedIndex, -1);
  assert.ok(started.body.leftStopAt);

  await request(app)
    .post("/transport/routes/route-1/trip/start")
    .set(as.driver)
    .send({ direction: "toHome" })
    .expect(409); // one trip at a time

  const at = (latitude, longitude, accuracy) =>
    request(app)
      .post("/transport/routes/route-1/trip/location")
      .set(as.driver)
      .send({ latitude, longitude, accuracy })
      .expect(200);

  // A rough reading (indoors, or "approximate location") right at the stop
  // moves the bus on the map but doesn't count as arriving.
  const rough = await at(33.3381, 44.2701, 900);
  assert.equal(rough.body.reachedIndex, -1);
  assert.equal(rough.body.latitude, 33.3381);

  // Reaching Al-Ghazaliya, driving away from it, then reaching Al-Adel.
  const first = await at(33.3381, 44.2701, 12);
  assert.equal(first.body.reachedIndex, 0);
  assert.equal(first.body.leftStopAt, null);
  assert.ok((await at(33.334, 44.285)).body.leftStopAt);
  const reached = await at(33.3301, 44.3001);
  assert.equal(reached.body.reachedIndex, 1);
  assert.equal(reached.body.leftStopAt, null);

  await request(app)
    .post("/transport/routes/route-1/trip/boarding")
    .set(as.driver)
    .send({ studentId: "STU-2026-0152", status: "onBoard" })
    .expect(200);
  await request(app)
    .post("/transport/routes/route-1/trip/delay")
    .set(as.driver)
    .send({ minutes: 5, reason: "Traffic" })
    .expect(200);

  // Families see the same trip.
  const seen = await request(app).get("/transport/routes/route-1/trip").set(as.parent).expect(200);
  assert.equal(seen.body.trip.delayMinutes, 5);
  assert.deepEqual(seen.body.trip.boardedIds, ["STU-2026-0152"]);

  await request(app)
    .post("/transport/routes/route-1/trip/end")
    .set(as.driver)
    .send({ earlyReason: "Flat tyre" })
    .expect(200);
  const after = await request(app).get("/transport/routes/route-1/trip").set(as.student);
  assert.equal(after.body.trip, null);
  assert.ok(after.body.finished.toSchool);
});

test("outside test mode the clock and calendar decide", async () => {
  await request(app)
    .put("/transport/settings")
    .set(as.admin)
    .send({ opensBeforeMinutes: 45, closesAfterMinutes: 60, testMode: false })
    .expect(204);
  // The morning trip was already driven today (or there's no school today).
  const res = await request(app)
    .post("/transport/routes/route-1/trip/start")
    .set(as.driver)
    .send({ direction: "toSchool" })
    .expect(409);
  assert.ok(res.body.error);
});

test("door to door: the family shares home, the school reads WhatsApp links", async () => {
  // Outside Iraq is refused (a wrong link or a typo).
  await request(app)
    .put("/transport/students/STU-2026-0142/home")
    .set(as.parent)
    .send({ latitude: 48.85, longitude: 2.35 })
    .expect(400);

  const shared = await request(app)
    .put("/transport/students/STU-2026-0142/home")
    .set(as.parent)
    .send({ latitude: 33.301, longitude: 44.336, note: "Green gate" })
    .expect(200);
  assert.equal(shared.body.setBy, "family");

  // Another family's child: no.
  await request(app)
    .put("/transport/students/STU-2026-0150/home")
    .set(as.parent)
    .send({ latitude: 33.3, longitude: 44.3 })
    .expect(403);

  const home = await request(app).get("/transport/students/STU-2026-0142/home").set(as.admin);
  assert.equal(home.body.note, "Green gate");

  const read = await request(app)
    .post("/transport/read-location")
    .set(as.admin)
    .send({ text: "Our home: https://maps.google.com/maps?q=33.3121%2C44.3612&z=17&hl=en" })
    .expect(200);
  assert.deepEqual(read.body, { latitude: 33.3121, longitude: 44.3612 });
  await request(app)
    .post("/transport/read-location")
    .set(as.admin)
    .send({ text: "near the big mosque" })
    .expect(400);
});
