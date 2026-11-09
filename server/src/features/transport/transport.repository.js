// SQL for school buses. Always limited to one institution.
const config = require("../../config");
const { query, queryOne, transaction } = require("../../db/database");

// ---------- Settings ----------

async function findSettings(institutionId) {
  const row = await queryOne(
    `SELECT opens_before_minutes AS "opensBeforeMinutes",
            closes_after_minutes AS "closesAfterMinutes", test_mode AS "testMode"
     FROM transport_settings WHERE institution_id = $1`,
    [institutionId],
  );
  // Test mode (trips at any hour) is for trying the app on this PC; a real
  // school starts with it off.
  return row ?? { opensBeforeMinutes: 45, closesAfterMinutes: 60, testMode: !config.isProduction };
}

function saveSettings(institutionId, s) {
  return query(
    `INSERT INTO transport_settings
       (institution_id, opens_before_minutes, closes_after_minutes, test_mode)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (institution_id) DO UPDATE SET
       opens_before_minutes = $2, closes_after_minutes = $3, test_mode = $4`,
    [institutionId, s.opensBeforeMinutes, s.closesAfterMinutes, s.testMode],
  );
}

// ---------- Lines ----------

/** Where a line ends when the school hasn't put itself on the map yet. */
const BAGHDAD = { latitude: 33.3152, longitude: 44.3661 };

/**
 * Lines with their stops in morning order, ending at the school.
 * [where] filters bus_routes (alias r), e.g. "r.id = $2".
 */
async function findRoutes(institutionId, where = "true", params = []) {
  const routes = await query(
    `SELECT r.id, r.name, r.bus_number AS "busNumber", r.plate_number AS "plateNumber",
            COALESCE(r.driver_id, '') AS "driverId", COALESCE(d.name, '') AS "driverName",
            COALESCE(d.phone, '') AS "driverPhone",
            r.supervisor_name AS "supervisorName", r.supervisor_phone AS "supervisorPhone",
            r.capacity, r.school_morning_minute, r.school_afternoon_minute,
            r.road_to_school AS "roadToSchool", r.road_to_home AS "roadToHome",
            (SELECT count(*)::int FROM route_students rs WHERE rs.route_id = r.id)
              AS "studentCount",
            i.name AS school_name, i.address AS school_address,
            i.latitude AS school_lat, i.longitude AS school_lng
     FROM bus_routes r
     JOIN institutions i ON i.id = r.institution_id
     LEFT JOIN users d ON d.id = r.driver_id
     WHERE r.institution_id = $1 AND ${where}
     ORDER BY r.name`,
    [institutionId, ...params],
  );
  if (routes.length === 0) return [];

  const stops = await query(
    `SELECT id, route_id, name, landmark, latitude, longitude,
            morning_minute AS "morningMinute", afternoon_minute AS "afternoonMinute"
     FROM bus_stops WHERE route_id = ANY($1) ORDER BY position`,
    [routes.map((r) => r.id)],
  );

  return routes.map((r) => {
    const {
      school_morning_minute, school_afternoon_minute, school_name,
      school_address, school_lat, school_lng, ...route
    } = r;
    return {
      ...route,
      stops: [
        ...stops
          .filter((s) => s.route_id === r.id)
          .map(({ route_id, ...stop }) => stop),
        {
          id: "school",
          name: school_name,
          landmark: school_address || "Main gate",
          latitude: school_lat ?? BAGHDAD.latitude,
          longitude: school_lng ?? BAGHDAD.longitude,
          morningMinute: school_morning_minute,
          afternoonMinute: school_afternoon_minute,
        },
      ],
    };
  });
}

async function findRoute(institutionId, routeId) {
  const [route] = await findRoutes(institutionId, "r.id = $2", [routeId]);
  return route ?? null;
}

async function findDriverRoute(institutionId, driverId) {
  const [route] = await findRoutes(institutionId, "r.driver_id = $2", [driverId]);
  return route ?? null;
}

/**
 * Creates or updates a line and its stops in one go. Stops keep their IDs,
 * so riders stay on them; stops left out are deleted with their riders.
 */
async function saveRoute(institutionId, routeId, r) {
  return transaction(async (tx) => {
    // A driver drives one bus: take them off any other line.
    if (r.driverId) {
      await tx.query(
        `UPDATE bus_routes SET driver_id = NULL
         WHERE institution_id = $1 AND driver_id = $2 AND id <> COALESCE($3, '')`,
        [institutionId, r.driverId, routeId],
      );
    }

    const school = r.stops.find((s) => s.id === "school");
    const values = [
      r.name, r.busNumber, r.plateNumber, r.driverId || null, r.supervisorName,
      r.supervisorPhone, r.capacity, school?.morningMinute ?? 465,
      school?.afternoonMinute ?? 800,
    ];

    let id = routeId;
    if (id) {
      const updated = await tx.query(
        `UPDATE bus_routes SET name = $3, bus_number = $4, plate_number = $5,
           driver_id = $6, supervisor_name = $7, supervisor_phone = $8, capacity = $9,
           school_morning_minute = $10, school_afternoon_minute = $11
         WHERE institution_id = $1 AND id = $2 RETURNING id`,
        [institutionId, id, ...values],
      );
      if (updated.length === 0) return null;
    } else {
      ({ id } = await tx.queryOne(
        `INSERT INTO bus_routes (institution_id, name, bus_number, plate_number,
           driver_id, supervisor_name, supervisor_phone, capacity,
           school_morning_minute, school_afternoon_minute)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id`,
        [institutionId, ...values],
      ));
    }

    const pickUps = r.stops.filter((s) => s.id !== "school");
    const existing = (
      await tx.query("SELECT id FROM bus_stops WHERE route_id = $1", [id])
    ).map((s) => s.id);
    const kept = pickUps.filter((s) => existing.includes(s.id)).map((s) => s.id);

    await tx.query(
      "DELETE FROM bus_stops WHERE route_id = $1 AND NOT (id = ANY($2))",
      [id, kept],
    );
    for (const [position, s] of pickUps.entries()) {
      const fields = [s.name, s.landmark, s.latitude, s.longitude, s.morningMinute, s.afternoonMinute, position];
      if (kept.includes(s.id)) {
        await tx.query(
          `UPDATE bus_stops SET name = $2, landmark = $3, latitude = $4, longitude = $5,
             morning_minute = $6, afternoon_minute = $7, position = $8
           WHERE id = $1`,
          [s.id, ...fields],
        );
      } else {
        await tx.query(
          `INSERT INTO bus_stops (route_id, name, landmark, latitude, longitude,
             morning_minute, afternoon_minute, position)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [id, ...fields],
        );
      }
    }
    return id;
  });
}

/** The roads worked out for both trips of a line (null = straight lines). */
function saveRoads(routeId, toSchool, toHome) {
  return query(
    "UPDATE bus_routes SET road_to_school = $2, road_to_home = $3 WHERE id = $1",
    [routeId, toSchool && JSON.stringify(toSchool), toHome && JSON.stringify(toHome)],
  );
}

/** Lines whose roads were never worked out, in every school. */
function findRoutesWithoutRoads() {
  return query(
    "SELECT id, institution_id AS \"institutionId\" FROM bus_routes WHERE road_to_school IS NULL",
  );
}

async function deleteRoute(institutionId, routeId) {
  const rows = await query(
    "DELETE FROM bus_routes WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, routeId],
  );
  return rows.length > 0;
}

// ---------- Riders ----------

const RIDER = `rs.student_id AS id, u.name, rs.stop_id AS "stopId",
  COALESCE(u.class_name, '') AS "className",
  COALESCE(p.id, '') AS "parentId", COALESCE(p.name, 'No parent linked') AS "parentName",
  COALESCE(p.phone, '') AS "parentPhone",
  rs.not_riding_on::text AS "notRidingOn"`;

// The first parent on file for the child.
const RIDER_FROM = `FROM route_students rs
  JOIN users u ON u.id = rs.student_id
  LEFT JOIN LATERAL (
    SELECT pu.id, pu.name, pu.phone FROM parent_children pc
    JOIN users pu ON pu.id = pc.parent_id
    WHERE pc.child_id = rs.student_id ORDER BY pu.id LIMIT 1
  ) p ON true
  LEFT JOIN bus_stops s ON s.id = rs.stop_id`;

function findRiders(routeId) {
  return query(
    `SELECT ${RIDER} ${RIDER_FROM} WHERE rs.route_id = $1 ORDER BY s.position, u.name`,
    [routeId],
  );
}

function findRiding(studentId) {
  return queryOne(
    `SELECT rs.route_id AS "routeId", ${RIDER} ${RIDER_FROM} WHERE rs.student_id = $1`,
    [studentId],
  );
}

/** Adds the student, moves them to another stop, or to this bus from another. */
function saveRider(routeId, studentId, stopId) {
  return query(
    `INSERT INTO route_students (student_id, route_id, stop_id) VALUES ($1, $2, $3)
     ON CONFLICT (student_id) DO UPDATE SET route_id = $2, stop_id = $3`,
    [studentId, routeId, stopId],
  );
}

async function removeRider(routeId, studentId) {
  const rows = await query(
    "DELETE FROM route_students WHERE route_id = $1 AND student_id = $2 RETURNING student_id",
    [routeId, studentId],
  );
  return rows.length > 0;
}

/** [day] is the school's date ("2026-11-05"), or null when they ride again. */
function setNotRidingOn(studentId, day) {
  return query("UPDATE route_students SET not_riding_on = $2 WHERE student_id = $1", [
    studentId,
    day,
  ]);
}

/** Students of the school who don't ride any bus. */
function findStudentsWithoutBus(institutionId) {
  return query(
    `SELECT u.id, u.name, u.class_name AS "className",
            h.latitude AS "homeLatitude", h.longitude AS "homeLongitude"
     FROM users u LEFT JOIN student_homes h ON h.student_id = u.id
     WHERE u.institution_id = $1 AND u.role = 'student' AND u.is_active
       AND NOT EXISTS (SELECT 1 FROM route_students rs WHERE rs.student_id = u.id)
     ORDER BY u.class_name, u.name`,
    [institutionId],
  );
}

// ---------- Homes (door-to-door) ----------

const HOME = `latitude, longitude, note, set_by AS "setBy", updated_at AS "updatedAt"`;

function findHome(studentId) {
  return queryOne(`SELECT ${HOME} FROM student_homes WHERE student_id = $1`, [studentId]);
}

function saveHome(studentId, h, setBy) {
  return queryOne(
    `INSERT INTO student_homes (student_id, latitude, longitude, note, set_by)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (student_id) DO UPDATE SET latitude = $2, longitude = $3,
       note = $4, set_by = $5, updated_at = now()
     RETURNING ${HOME}`,
    [studentId, h.latitude, h.longitude, h.note, setBy],
  );
}

// ---------- Trips ----------

const TRIP = `id, direction, started_at AS "startedAt", ended_at AS "endedAt",
  early_reason AS "earlyReason", stop_ids AS "stopIds", reached_at AS "reachedAt",
  reached_index AS "reachedIndex", left_stop_at AS "leftStopAt",
  delay_minutes AS "delayMinutes", delay_reason AS "delayReason",
  latitude, longitude, position_at AS "positionAt",
  boarded_ids AS "boardedIds", absent_ids AS "absentIds", alerts_sent AS "alertsSent"`;

/** Today's trips of a line, the running one first. */
function findTodaysTrips(routeId, day) {
  return query(
    `SELECT ${TRIP} FROM bus_trips WHERE route_id = $1 AND trip_date = $2
     ORDER BY ended_at NULLS FIRST`,
    [routeId, day],
  );
}

async function startTrip(routeId, day, direction, stopIds) {
  // Test mode may drive a trip twice in a day: the new one replaces it.
  await query(
    "DELETE FROM bus_trips WHERE route_id = $1 AND trip_date = $2 AND direction = $3",
    [routeId, day, direction],
  );
  // The bus starts wherever the driver is, on its way to the first stop
  // (reached_index -1); GPS or the driver says when it gets there.
  return queryOne(
    `INSERT INTO bus_trips (route_id, direction, trip_date, stop_ids, reached_at,
                            reached_index, left_stop_at)
     VALUES ($1, $2, $3, $4, $5, -1, now()) RETURNING ${TRIP}`,
    [routeId, direction, day, stopIds, stopIds.map(() => null)],
  );
}

/** Saves the fields of [trip] that move during a trip. */
/**
 * Who watches a line's trip: its riders, their parents, the driver and the
 * school office.
 */
async function tripWatchers(institutionId, route) {
  const rows = await query(
    `SELECT student_id AS id FROM route_students WHERE route_id = $1
     UNION SELECT pc.parent_id FROM parent_children pc
       JOIN route_students rs ON rs.student_id = pc.child_id WHERE rs.route_id = $1
     UNION SELECT id FROM users WHERE institution_id = $2 AND role = 'admin'
     UNION SELECT driver_id FROM bus_routes WHERE id = $1 AND driver_id IS NOT NULL`,
    [route.id, institutionId],
  );
  return rows.map((r) => r.id);
}

function saveTrip(trip) {
  return query(
    `UPDATE bus_trips SET reached_at = $2, reached_index = $3, left_stop_at = $4,
       delay_minutes = $5, delay_reason = $6, latitude = $7, longitude = $8,
       position_at = $9, boarded_ids = $10, absent_ids = $11, ended_at = $12,
       early_reason = $13, alerts_sent = $14
     WHERE id = $1`,
    [
      trip.id, trip.reachedAt, trip.reachedIndex, trip.leftStopAt,
      trip.delayMinutes, trip.delayReason, trip.latitude, trip.longitude,
      trip.positionAt, trip.boardedIds, trip.absentIds, trip.endedAt,
      trip.earlyReason, trip.alertsSent,
    ],
  );
}

module.exports = {
  tripWatchers,
  findSettings,
  saveSettings,
  findRoutes,
  findRoute,
  findDriverRoute,
  saveRoute,
  deleteRoute,
  saveRoads,
  findRoutesWithoutRoads,
  findRiders,
  findRiding,
  saveRider,
  removeRider,
  setNotRidingOn,
  findStudentsWithoutBus,
  findHome,
  saveHome,
  findTodaysTrips,
  startTrip,
  saveTrip,
};
