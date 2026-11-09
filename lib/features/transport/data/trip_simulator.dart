import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/trip_model.dart';

/// MOCK ONLY: builds the trip from the timetable, as if the bus were exactly on
/// time (used when no driver is reporting).
TripModel simulateTrip({
  required BusRouteModel route,
  required DateTime now,
  required bool isSchoolDay,
}) {
  if (!isSchoolDay || route.stops.isEmpty) {
    return TripModel.none(updatedAt: now);
  }

  final morning = now.hour < 12;
  final stops = morning ? route.stops : route.stops.reversed.toList();
  final day = DateTime(now.year, now.month, now.day);
  final times = [
    for (final stop in stops)
      day.add(
        Duration(minutes: morning ? stop.morningMinute : stop.afternoonMinute),
      ),
  ];

  final lastReached = times.lastIndexWhere((t) => !t.isAfter(now));

  final TripPhase phase;
  var from = 0;
  var fraction = 0.0;

  if (lastReached == -1) {
    phase = TripPhase.notStarted;
  } else if (lastReached == stops.length - 1) {
    phase = TripPhase.arrived;
    from = stops.length - 1;
  } else {
    phase = TripPhase.onTheWay;
    from = lastReached;

    final leg = times[lastReached + 1].difference(times[lastReached]);
    fraction = now.difference(times[lastReached]).inSeconds / leg.inSeconds;
  }

  final direction = morning ? TripDirection.toSchool : TripDirection.toHome;
  final (lat, lng) = positionOnTrip(route, direction, stops, from, fraction);

  return TripModel(
    direction: direction,
    phase: phase,
    stops: stops,
    plannedTimes: times,
    lastReachedIndex: lastReached,
    latitude: lat,
    longitude: lng,
    updatedAt: now,
    road: route.roadFor(direction),
  );
}

/// Where the bus is [fraction] (0–1) of the way from stops[from] to the next
/// stop: on the streets when the line's road is known, else in a straight line.
(double, double) positionOnTrip(
  BusRouteModel route,
  TripDirection direction,
  List<BusStopModel> stops,
  int from,
  double fraction,
) {
  final to = from + 1 < stops.length ? from + 1 : from;
  final road = route.roadFor(direction);
  if (road != null && to != from && from < road.legs.length) {
    final p = road.along(from, fraction.clamp(0.0, 1.0));
    return (p.latitude, p.longitude);
  }
  return between(stops[from], stops[to], fraction);
}

/// A point [fraction] (0–1) of the way from [a] to [b], in a straight line.
/// Good enough for test mode; real positions come from GPS.
(double, double) between(BusStopModel a, BusStopModel b, double fraction) {
  final f = fraction.clamp(0.0, 1.0);

  return (
    a.latitude + (b.latitude - a.latitude) * f,
    a.longitude + (b.longitude - a.longitude) * f,
  );
}
