const repo = require("./transport.repository");
const { notify, admins, withParents } = require("../notifications/notify");
const { dayText, distanceMetres } = require("./trip-rules");
const { msg } = require("../../i18n");

const NEAR_MINUTES = 5;
const METRES_PER_MINUTE = (7 * 60) / 1.3;

const BUS_PAGE = "/bus";
const lineRoute = (route) => `/transport/${route.id}`;

async function families(route, stopId = null) {
  const today = dayText(new Date());
  const riders = (await repo.findRiders(route.id)).filter(
    (r) => r.notRidingOn !== today && (!stopId || r.stopId === stopId),
  );
  return withParents(riders.map((r) => r.id));
}

async function parentsOf(studentId) {
  return (await withParents([studentId])).filter((id) => id !== studentId);
}

async function tellOffice(institutionId, route, title, body) {
  await notify(institutionId, await admins(institutionId), {
    type: "transport",
    title,
    body,
    route: lineRoute(route),
  });
}

const stopOf = (route, trip, index) =>
  route.stops.find((s) => s.id === trip.stopIds[index]);

async function tripStarted(institutionId, route, trip) {
  const title =
    trip.direction === "toSchool"
      ? msg("Bus {0} started the morning trip", route.busNumber)
      : msg("Bus {0} started the afternoon trip", route.busNumber);
  await notify(institutionId, await families(route), {
    type: "transport",
    title,
    body: msg("Follow it live in the app"),
    route: BUS_PAGE,
  });
  await tellOffice(institutionId, route, title, route.driverName || msg("No driver named"));
}

async function leftStop(institutionId, route, trip) {
  const next = stopOf(route, trip, trip.reachedIndex + 1);
  if (!next || next.id === "school") return;
  await notify(institutionId, await families(route, next.id), {
    type: "transport",
    title: msg("Bus {0} is on its way", route.busNumber),
    body: msg("Next stop: {0}", next.name),
    route: BUS_PAGE,
  });
}

async function maybeNear(institutionId, route, trip) {
  const next = stopOf(route, trip, trip.reachedIndex + 1);
  if (!next || next.id === "school" || trip.latitude == null) return false;
  const key = `near:${next.id}`;
  if (trip.alertsSent.includes(key)) return false;

  const metres = distanceMetres(trip.latitude, trip.longitude, next.latitude, next.longitude);
  const minutes = Math.max(1, Math.round(metres / METRES_PER_MINUTE));
  if (minutes > NEAR_MINUTES) return false;

  trip.alertsSent = [...trip.alertsSent, key];
  await notify(institutionId, await families(route, next.id), {
    type: "transport",
    title: msg("Bus {0} is about {1} min away", route.busNumber, minutes),
    body: trip.direction === "toSchool"
      ? msg("Please be ready at {0}", next.name)
      : msg("Arriving at {0}", next.name),
    route: BUS_PAGE,
  });
  return true;
}

async function arrived(institutionId, route, trip, index) {
  const stop = stopOf(route, trip, index);
  if (!stop) return;
  const isLast = index === trip.stopIds.length - 1;

  if (trip.direction === "toSchool") {
    if (isLast) {
      await notify(institutionId, await withParents(trip.boardedIds), {
        type: "transport",
        title: msg("Bus {0} arrived at school", route.busNumber),
        body: msg("Your child is at school"),
        route: BUS_PAGE,
      });
    } else {
      await notify(institutionId, await families(route, stop.id), {
        type: "transport",
        title: msg("Bus {0} is at {1}", route.busNumber, stop.name),
        body: msg("Please get on now"),
        route: BUS_PAGE,
      });
    }
  } else if (stop.id !== "school") {
    await notify(institutionId, await families(route, stop.id), {
      type: "transport",
      title: msg("Dropped off at home stop"),
      body: msg("Bus {0} at {1}", route.busNumber, stop.name),
      route: BUS_PAGE,
    });
  }
}

async function boarding(institutionId, route, trip, studentId, status) {
  const here = stopOf(route, trip, Math.max(0, trip.reachedIndex));
  const rider = (await repo.findRiders(route.id)).find((r) => r.id === studentId);
  if (!rider) return;

  if (status === "onBoard") {
    await notify(institutionId, await withParents([studentId]), {
      type: "transport",
      title: msg("{0} is on bus {1}", rider.name, route.busNumber),
      body: here ? msg("Got on at {0}", here.name) : "",
      route: BUS_PAGE,
    });
  } else if (status === "absent") {
    await notify(institutionId, await parentsOf(studentId), {
      type: "transport",
      title: msg("{0} was not at the bus stop", rider.name),
      body: here
        ? msg("Bus {0} left {1} without them", route.busNumber, here.name)
        : msg("Bus {0} left the stop without them", route.busNumber),
      route: BUS_PAGE,
    });
  }
}

async function delayed(institutionId, route, trip) {
  const title = msg("Bus {0} is running {1} min late", route.busNumber, trip.delayMinutes);
  await notify(institutionId, await families(route), {
    type: "transport",
    title,
    body: trip.delayReason ? msg(trip.delayReason) : "",
    route: BUS_PAGE,
  });
  await tellOffice(institutionId, route, title, trip.delayReason ? msg(trip.delayReason) : "");
}

async function endedEarly(institutionId, route, trip) {
  const title =
    trip.direction === "toSchool"
      ? msg("Bus {0} ended the morning trip early", route.busNumber)
      : msg("Bus {0} ended the afternoon trip early", route.busNumber);
  await notify(institutionId, await families(route), {
    type: "transport",
    title,
    body: msg("{0} · the school will contact you", msg(trip.earlyReason)),
    route: BUS_PAGE,
  });
  await tellOffice(
    institutionId,
    route,
    title,
    msg("{0} · please contact the families", msg(trip.earlyReason)),
  );
}

async function ridingChanged(institutionId, studentId, notRiding) {
  const riding = await repo.findRiding(studentId);
  if (!riding) return;
  const route = await repo.findRoute(institutionId, riding.routeId);
  await notify(institutionId, [route?.driverId], {
    type: "transport",
    title: notRiding
      ? msg("{0} won't ride today", riding.name)
      : msg("{0} will ride today", riding.name),
    body: msg("Told by {0}", riding.parentName),
    route: "/home",
  });
}

async function tripChanged(institutionId, route, before, after) {
  for (let i = before.reachedIndex + 1; i <= after.reachedIndex; i++) {
    await arrived(institutionId, route, after, i);
  }
  const left =
    !before.leftStopAt && after.leftStopAt &&
    after.reachedIndex === before.reachedIndex && after.reachedIndex >= 0;
  if (left) await leftStop(institutionId, route, after);

  for (const id of after.boardedIds.filter((id) => !before.boardedIds.includes(id))) {
    await boarding(institutionId, route, after, id, "onBoard");
  }
  for (const id of after.absentIds.filter((id) => !before.absentIds.includes(id))) {
    await boarding(institutionId, route, after, id, "absent");
  }
  if (after.delayMinutes > before.delayMinutes) await delayed(institutionId, route, after);
  if (!before.endedAt && after.endedAt && after.earlyReason) {
    await endedEarly(institutionId, route, after);
  }
}

module.exports = {
  tripChanged,
  tripStarted,
  leftStop,
  maybeNear,
  arrived,
  boarding,
  delayed,
  endedEarly,
  ridingChanged,
};
