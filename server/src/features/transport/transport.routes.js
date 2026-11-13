// School buses.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const institution = require("../institution/institution.repository");
const users = require("../users/users.repository");
const { query } = require("../../db/database");
const hub = require("../../realtime/hub");
const repo = require("./transport.repository");
const { updateRoads } = require("./roads");
const alerts = require("./alerts");
const { searchPlaces, readLocation, inIraq } = require("./maps");
const { dayText, dayOffReason, tripBlock, distanceMetres } = require("./trip-rules");
const { log } = require("../activity/log");
const { msg } = require("../../i18n");

const router = express.Router();
router.use(requireAuth);

/** Test mode: how long the bus "drives" between stops without GPS. */
const DEMO_DRIVE_MS = 20_000;
/** GPS: the bus has reached a stop within this distance… */
const ARRIVED_METRES = 80;
/** …and has left it beyond this one. */
const LEFT_METRES = 150;
/** A GPS point older than this no longer moves the bus. */
const GPS_FRESH_MS = 30_000;
/**
 * Rougher readings move the bus on the map but never decide "arrived" or
 * "left" (indoors, or a phone sharing only its rough area, is off by hundreds
 * of metres).
 */
const DECIDES_WITHIN_METRES = 100;

// ---------- Helpers ----------

async function routeOr404(req, routeId = req.params.id) {
  const route = await repo.findRoute(req.user.institutionId, routeId);
  if (!route) throw new HttpError(404, "Bus line not found.");
  return route;
}

/** The line's driver or an administrator. */
function requireDriverOf(req, route) {
  if (req.user.role === "admin") return;
  if (req.user.role !== "driver" || route.driverId !== req.user.id) {
    throw new HttpError(403, "Only this bus's driver can do that.");
  }
}

/** The student themself, their parent, or an administrator. */
async function requireFamilyOf(req, studentId) {
  if (req.user.role === "admin" || req.user.id === studentId) return;
  if (req.user.role === "parent") {
    const children = await users.findChildren(req.user.id);
    if (children.some((c) => c.id === studentId)) return;
  }
  throw new HttpError(403, "You don't have access to this student.");
}

async function studyYear(institutionId) {
  const year = await institution.findCurrentYear(institutionId);
  if (!year) return null;
  return {
    start: year.start,
    end: year.end,
    workingDays: year.working_days,
    holidays: await institution.findHolidays(year.id),
  };
}

const riderJson = ({ notRidingOn, ...rider }) => ({
  ...rider,
  notRidingToday: notRidingOn === dayText(new Date()),
});

/**
 * Today's trips of a line. Moves a test-mode bus on when it has "driven"
 * long enough without GPS, so the demo works on a computer.
 */
async function todaysTrips(institutionId, route, settings) {
  const trips = await repo.findTodaysTrips(route.id, dayText(new Date()));
  const running = trips.find((t) => !t.endedAt) ?? null;

  if (running && running.leftStopAt && settings.testMode && !hasFreshGps(running)) {
    if (Date.now() - new Date(running.leftStopAt) >= DEMO_DRIVE_MS) {
      const before = { ...running };
      arrive(running);
      await repo.saveTrip(running);
      await alerts.tripChanged(institutionId, route, before, running);
      await tellWatchers(institutionId, route);
    }
  }

  const finished = {};
  for (const t of trips) if (t.endedAt) finished[t.direction] = t.endedAt;
  return { running, finished };
}

const hasFreshGps = (trip) =>
  trip.positionAt && Date.now() - new Date(trip.positionAt) < GPS_FRESH_MS;

/** The bus reached the next stop. */
function arrive(trip) {
  if (trip.reachedIndex >= trip.stopIds.length - 1) return;
  trip.reachedIndex += 1;
  trip.reachedAt = [...trip.reachedAt];
  trip.reachedAt[trip.reachedIndex] = new Date();
  trip.leftStopAt = null;
}

async function runningTripOr409(institutionId, route, settings) {
  const { running } = await todaysTrips(institutionId, route, settings);
  if (!running) throw new HttpError(409, "The bus is not on a trip.");
  return running;
}

// ---------- Settings ----------

// GET /transport/settings -> { opensBeforeMinutes, closesAfterMinutes, testMode }
router.get("/settings", async (req, res) => {
  res.json(await repo.findSettings(req.user.institutionId));
});

// PUT /transport/settings -> 204  (admin)
router.put("/settings", requireRole("admin"), async (req, res) => {
  const body = validate(
    z.object({
      opensBeforeMinutes: z.number().int().min(0).max(240),
      closesAfterMinutes: z.number().int().min(0).max(240),
      testMode: z.boolean(),
    }),
    req.body,
  );
  await repo.saveSettings(req.user.institutionId, body);
  res.status(204).end();
});

// ---------- Lines ----------

const minute = z.number().int().min(0).max(24 * 60 - 1);
const routeFields = z.object({
  name: z.string().trim().min(2).max(80),
  busNumber: z.string().trim().min(1).max(10),
  plateNumber: z.string().trim().max(30).default(""),
  driverId: z.string().trim().default(""),
  supervisorName: z.string().trim().max(80).default(""),
  supervisorPhone: z.string().trim().max(30).default(""),
  capacity: z.number().int().min(1).max(100),
  // Morning order; the "school" stop only carries the school's times.
  stops: z
    .array(
      z.object({
        id: z.string().default(""),
        name: z.string().trim().min(1).max(80),
        landmark: z.string().trim().max(120).default(""),
        latitude: z.number().min(-90).max(90),
        longitude: z.number().min(-180).max(180),
        morningMinute: minute,
        afternoonMinute: minute,
      }),
    )
    .max(40),
});

async function checkDriver(req, driverId) {
  if (!driverId) return;
  const driver = await users.findById(driverId);
  if (!driver || driver.role !== "driver" || driver.institution_id !== req.user.institutionId) {
    throw new HttpError(400, "Choose a driver of this school.");
  }
}

async function saveRoute(req, res, routeId) {
  const body = validate(routeFields, req.body);
  await checkDriver(req, body.driverId);
  try {
    const id = await repo.saveRoute(req.user.institutionId, routeId, body);
    if (!id) throw new HttpError(404, "Bus line not found.");
    // Draw the line on the roads now, so every map shows streets.
    await updateRoads(req.user.institutionId, id);
    res.status(routeId ? 200 : 201).json(await repo.findRoute(req.user.institutionId, id));
  } catch (e) {
    if (e.code === "23505") throw new HttpError(409, "Another line has that name.");
    throw e;
  }
}

// GET /transport/places?q=Yarmouk hospital -> [{ name, address, latitude, longitude }]
// (admin) Finds a place by name to put a stop there.
router.get("/places", requireRole("admin"), async (req, res) => {
  const { q } = validate(z.object({ q: z.string().trim().min(2).max(120) }), req.query);
  const school = await institution.findInstitution(req.user.institutionId);
  try {
    res.json(await searchPlaces(q, school.latitude == null ? null : school));
  } catch {
    throw new HttpError(503, "Place search is not reachable right now. Tap the map instead.");
  }
});

// POST /transport/routes/:id/road -> route  (admin) Works the road out again.
router.post("/routes/:id/road", requireRole("admin"), async (req, res) => {
  const route = await routeOr404(req);
  await updateRoads(req.user.institutionId, route.id);
  res.json(await repo.findRoute(req.user.institutionId, route.id));
});

// GET /transport/routes -> [route]
router.get("/routes", async (req, res) => {
  res.json(await repo.findRoutes(req.user.institutionId));
});

// GET /transport/routes/:id -> route
router.get("/routes/:id", async (req, res) => {
  res.json(await routeOr404(req));
});

// POST /transport/routes -> route  (admin)
router.post("/routes", requireRole("admin"), (req, res) => saveRoute(req, res, null));

// PATCH /transport/routes/:id -> route  (admin)
router.patch("/routes/:id", requireRole("admin"), (req, res) =>
  saveRoute(req, res, req.params.id),
);

// DELETE /transport/routes/:id -> 204  (admin; not during a trip)
router.delete("/routes/:id", requireRole("admin"), async (req, res) => {
  const route = await routeOr404(req);
  const { running } = await todaysTrips(
    req.user.institutionId,
    route,
    await repo.findSettings(req.user.institutionId),
  );
  if (running) {
    throw new HttpError(409, "The bus is on a trip. Delete the line after the trip ends.");
  }
  await repo.deleteRoute(req.user.institutionId, route.id);
  res.status(204).end();
});

// GET /transport/driver-route -> route | null  (the signed-in driver's line)
router.get("/driver-route", requireRole("driver"), async (req, res) => {
  res.json(await repo.findDriverRoute(req.user.institutionId, req.user.id));
});

// ---------- Riders ----------

// GET /transport/routes/:id/students -> [rider]  (staff and the driver)
router.get(
  "/routes/:id/students",
  requireRole("admin", "teacher", "driver"),
  async (req, res) => {
    const route = await routeOr404(req);
    res.json((await repo.findRiders(route.id)).map(riderJson));
  },
);

// GET /transport/students-without-bus -> [{ id, name, className }]  (admin)
router.get("/students-without-bus", requireRole("admin"), async (req, res) => {
  res.json(await repo.findStudentsWithoutBus(req.user.institutionId));
});

// PUT /transport/routes/:id/students/:studentId { stopId } -> 204  (admin)
// Adds the student, moves them to another stop, or from another bus.
router.put(
  "/routes/:id/students/:studentId",
  requireRole("admin"),
  async (req, res) => {
    const route = await routeOr404(req);
    const { stopId } = validate(z.object({ stopId: z.string() }), req.body);
    if (!route.stops.some((s) => s.id === stopId && s.id !== "school")) {
      throw new HttpError(400, "Choose one of the line's stops.");
    }

    const student = await users.findById(req.params.studentId);
    if (!student || student.role !== "student" || student.institution_id !== req.user.institutionId) {
      throw new HttpError(400, "Choose a student of this school.");
    }

    const riding = await repo.findRiding(student.id);
    if (riding?.routeId !== route.id && route.studentCount >= route.capacity) {
      throw new HttpError(409, "Bus {0} is full ({1} seats).", [route.busNumber, route.capacity]);
    }
    await repo.saveRider(route.id, student.id, stopId);
    res.status(204).end();
  },
);

// DELETE /transport/routes/:id/students/:studentId -> 204  (admin)
router.delete(
  "/routes/:id/students/:studentId",
  requireRole("admin"),
  async (req, res) => {
    const route = await routeOr404(req);
    if (!(await repo.removeRider(route.id, req.params.studentId))) {
      throw new HttpError(404, "That student doesn't ride this bus.");
    }
    res.status(204).end();
  },
);

// GET /transport/students/:studentId -> { route, stopId, notRidingToday } | null
router.get("/students/:studentId", async (req, res) => {
  await requireFamilyOf(req, req.params.studentId);
  const riding = await repo.findRiding(req.params.studentId);
  if (!riding) return res.json(null);

  const rider = riderJson(riding);
  res.json({
    route: await repo.findRoute(req.user.institutionId, riding.routeId),
    stopId: rider.stopId,
    notRidingToday: rider.notRidingToday,
  });
});

// POST /transport/students/:studentId/not-riding { notRiding } -> 204
// The parent tells the driver the child won't ride today.
router.post("/students/:studentId/not-riding", async (req, res) => {
  await requireFamilyOf(req, req.params.studentId);
  const { notRiding } = validate(z.object({ notRiding: z.boolean() }), req.body);
  await repo.setNotRidingOn(req.params.studentId, notRiding ? dayText(new Date()) : null);
  await alerts.ridingChanged(req.user.institutionId, req.params.studentId, notRiding);
  res.status(204).end();
});

// ---------- Homes (door-to-door pick-up) ----------

// GET /transport/students/:studentId/home -> home | null  (family, admin)
router.get("/students/:studentId/home", async (req, res) => {
  await requireFamilyOf(req, req.params.studentId);
  res.json(await repo.findHome(req.params.studentId));
});

// PUT /transport/students/:studentId/home { latitude, longitude, note } -> home
// The family shares where they live, or the school sets it.
router.put("/students/:studentId/home", async (req, res) => {
  await requireFamilyOf(req, req.params.studentId);
  const body = validate(
    z
      .object({
        latitude: z.number(),
        longitude: z.number(),
        note: z.string().trim().max(200).default(""),
      })
      .refine(inIraq, { message: "That place is outside Iraq." }),
    req.body,
  );
  const setBy = req.user.role === "admin" ? "school" : "family";
  res.json(await repo.saveHome(req.params.studentId, body, setBy));
});

// POST /transport/read-location { text } -> { latitude, longitude }
// Reads a WhatsApp / Google Maps location link, or "33.31, 44.36".
router.post("/read-location", requireRole("admin", "parent", "student"), async (req, res) => {
  const { text } = validate(z.object({ text: z.string().trim().min(3).max(2000) }), req.body);
  let found = null;
  try {
    found = await readLocation(text);
  } catch {
    // The short link couldn't be followed: same answer as "not found".
  }
  if (!found) {
    throw new HttpError(400, "No place in Iraq found in that. Paste the location link from WhatsApp or Google Maps.",
    );
  }
  res.json(found);
});

// ---------- Trips ----------

// GET /transport/routes/:id/trip
//   -> { trip: running trip | null, finished: { toSchool?, toHome? }, serverTime }
// serverTime: phones' clocks are often a few minutes off; the app compares
// the trip's times with this clock, not its own.
router.get("/routes/:id/trip", async (req, res) => {
  const route = await routeOr404(req);
  const { running, finished } = await todaysTrips(
    req.user.institutionId,
    route,
    await repo.findSettings(req.user.institutionId),
  );
  res.json({ trip: running, finished, serverTime: new Date() });
});

// POST /transport/routes/:id/trip/start { direction } -> trip  (driver)
router.post("/routes/:id/trip/start", async (req, res) => {
  const route = await routeOr404(req);
  requireDriverOf(req, route);
  const { direction } = validate(
    z.object({ direction: z.enum(["toSchool", "toHome"]) }),
    req.body,
  );

  const settings = await repo.findSettings(req.user.institutionId);
  const { running, finished } = await todaysTrips(req.user.institutionId, route, settings);
  const block = tripBlock({
    route,
    direction,
    now: new Date(),
    settings,
    year: await studyYear(req.user.institutionId),
    doneToday: Boolean(finished[direction]),
    running: Boolean(running),
  });
  if (block) throw new HttpError(409, block.template ?? block, block.args ?? []);

  const stopIds = route.stops.map((s) => s.id);
  if (direction === "toHome") stopIds.reverse();
  const trip = await repo.startTrip(route.id, dayText(new Date()), direction, stopIds);
  await alerts.tripStarted(req.user.institutionId, route, trip);
  await tellWatchers(req.user.institutionId, route);
  await log(req.user, {
    kind: "transport",
    action: "trip.started",
    summary: msg(
      direction === "toSchool"
        ? "started the morning trip of bus {0} ({1})"
        : "started the afternoon trip of bus {0} ({1})",
      route.busNumber,
      route.name,
    ),
    studentIds: await riderIds(route.id),
    route: "/bus",
  });
  res.status(201).json(trip);
});

/** The students who ride a line (their parents see its trips). */
async function riderIds(routeId) {
  const rows = await query("SELECT student_id FROM route_students WHERE route_id = $1", [routeId]);
  return rows.map((r) => r.student_id);
}

/** Open apps watching this line reload its trip at once. */
async function tellWatchers(institutionId, route) {
  hub.publish(await repo.tripWatchers(institutionId, route), {
    type: "trip.updated",
    routeId: route.id,
  });
}

/**
 * Runs [change] on the running trip, saves it, tells everyone what changed
 * (see alerts.js) and returns it.
 */
function tripAction(change) {
  return async (req, res) => {
    const institutionId = req.user.institutionId;
    const route = await routeOr404(req);
    requireDriverOf(req, route);
    const settings = await repo.findSettings(institutionId);
    const trip = await runningTripOr409(institutionId, route, settings);
    const before = { ...trip };
    await change(trip, req, route);
    await alerts.maybeNear(institutionId, route, trip);
    await repo.saveTrip(trip);
    await alerts.tripChanged(institutionId, route, before, trip);
    await tellWatchers(institutionId, route);
    res.json(trip);
  };
}

// POST /transport/routes/:id/trip/leave -> trip  (driver leaves the stop)
router.post(
  "/routes/:id/trip/leave",
  tripAction((trip) => {
    if (!trip.leftStopAt && trip.reachedIndex < trip.stopIds.length - 1) {
      trip.leftStopAt = new Date();
    }
  }),
);

// POST /transport/routes/:id/trip/arrive -> trip
// The driver says they reached the next stop (when GPS is off or late).
router.post(
  "/routes/:id/trip/arrive",
  tripAction((trip) => {
    if (trip.leftStopAt) arrive(trip);
  }),
);

// POST /transport/routes/:id/trip/boarding { studentId, status } -> trip
router.post(
  "/routes/:id/trip/boarding",
  tripAction((trip, req) => {
    const { studentId, status } = validate(
      z.object({ studentId: z.string(), status: z.enum(["onBoard", "absent", "waiting"]) }),
      req.body,
    );
    trip.boardedIds = trip.boardedIds.filter((id) => id !== studentId);
    trip.absentIds = trip.absentIds.filter((id) => id !== studentId);
    if (status === "onBoard") trip.boardedIds.push(studentId);
    if (status === "absent") trip.absentIds.push(studentId);
  }),
);

// POST /transport/routes/:id/trip/delay { minutes, reason } -> trip
router.post(
  "/routes/:id/trip/delay",
  tripAction((trip, req) => {
    const { minutes, reason } = validate(
      z.object({ minutes: z.number().int().min(1).max(180), reason: z.string().trim().min(1).max(120) }),
      req.body,
    );
    trip.delayMinutes += minutes;
    trip.delayReason = reason;
  }),
);

// POST /transport/routes/:id/trip/end { earlyReason? } -> trip
router.post(
  "/routes/:id/trip/end",
  tripAction(async (trip, req, route) => {
    const { earlyReason } = validate(
      z.object({ earlyReason: z.string().trim().max(200).nullish() }),
      req.body ?? {},
    );
    trip.endedAt = new Date();
    trip.earlyReason = earlyReason ?? null;
    await log(req.user, {
      kind: "transport",
      action: "trip.ended",
      summary: earlyReason
        ? msg(
            trip.direction === "toSchool"
              ? "ended the morning trip of bus {0} early: {1}"
              : "ended the afternoon trip of bus {0} early: {1}",
            route.busNumber,
            earlyReason,
          )
        : msg(
            trip.direction === "toSchool"
              ? "ended the morning trip of bus {0}"
              : "ended the afternoon trip of bus {0}",
            route.busNumber,
          ),
      studentIds: await riderIds(route.id),
      route: "/bus",
    });
  }),
);

// POST /transport/routes/:id/trip/location { latitude, longitude, accuracy? } -> trip
// The driver's phone, every few seconds. Moves the bus on by itself:
// it leaves a stop when it drives away and reaches the next one when close.
// (Positions are never written to the log: where the children's bus was
// all day is nobody's business.)
router.post(
  "/routes/:id/trip/location",
  tripAction((trip, req, route) => {
    const { latitude, longitude, accuracy } = validate(
      z.object({
        latitude: z.number().min(-90).max(90),
        longitude: z.number().min(-180).max(180),
        accuracy: z.number().min(0).optional(),
      }),
      req.body,
    );
    trip.latitude = latitude;
    trip.longitude = longitude;
    trip.positionAt = new Date();
    if (accuracy != null && accuracy > DECIDES_WITHIN_METRES) return;

    const stop = (index) => route.stops.find((s) => s.id === trip.stopIds[index]);
    const distanceTo = (s) => distanceMetres(latitude, longitude, s.latitude, s.longitude);
    const isLast = trip.reachedIndex >= trip.stopIds.length - 1;

    // Standing at a stop: it leaves when it drives away. (Before the
    // first stop, leftStopAt is already set: it is on its way there.)
    if (!trip.leftStopAt && !isLast) {
      const here = stop(trip.reachedIndex);
      if (here && distanceTo(here) > LEFT_METRES) trip.leftStopAt = new Date();
    } else if (trip.leftStopAt) {
      const next = stop(trip.reachedIndex + 1);
      if (next && distanceTo(next) < ARRIVED_METRES) arrive(trip);
    }
  }),
);

module.exports = router;
