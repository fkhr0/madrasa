import 'package:latlong2/latlong.dart';

import '../data/trip_simulator.dart';
import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/trip_model.dart';
import '../repo/live_trip.dart';

/// A GPS point older than this no longer places the bus on the map.
const gpsFreshFor = Duration(seconds: 30);

/// A school bus in city traffic: about 25 km/h on average.
const cityMetresPerSecond = 7.0;

/// Builds the app's [TripModel] from a running trip as the server sends it (GET
/// /transport/routes/:id/trip → "trip").
TripModel tripFromServer({
  required BusRouteModel route,
  required Map<String, dynamic> json,
  required DateTime now,
  required bool testMode,
}) {
  final direction = TripDirection.values.byName(json['direction'] as String);
  final stops = <BusStopModel>[];
  final reachedAt = <DateTime?>[];
  final allReached = json['reachedAt'] as List;
  final stopIds = json['stopIds'] as List;
  for (var i = 0; i < stopIds.length; i++) {
    // A stop deleted during the trip is simply skipped.
    final stop = route.stops.where((s) => s.id == stopIds[i]).firstOrNull;
    if (stop == null) continue;
    stops.add(stop);
    reachedAt.add(_time(allReached[i]));
  }

  final day = DateTime(now.year, now.month, now.day);
  final toSchool = direction == TripDirection.toSchool;
  final planned = [
    for (final s in stops)
      day.add(
        Duration(minutes: toSchool ? s.morningMinute : s.afternoonMinute),
      ),
  ];

  // -1: the trip has started and the bus is driving to its first stop
  // from wherever the driver was.
  final reached = (json['reachedIndex'] as num).toInt().clamp(
    -1,
    stops.length - 1,
  );
  final leftAt = _time(json['leftStopAt']);
  final isAtStop = leftAt == null && reached >= 0;
  final positionAt = _time(json['positionAt']);
  final gpsFresh =
      positionAt != null && now.difference(positionAt) < gpsFreshFor;
  final demo = testMode && !gpsFresh;
  final busAt = gpsFresh
      ? LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        )
      : null;
  final road = stops.length == route.stops.length
      ? route.roadFor(direction)
      : null;

  // How long the bus takes to drive to stop [i] from the one before:
  // the road's driving time when known, else the timetable's.
  Duration leg(int i) {
    if (demo) return LiveTrip.demoDriveTime;
    if (road != null) return Duration(seconds: road.legSeconds[i - 1]);
    final planned_ = planned[i].difference(planned[i - 1]).abs();
    return planned_ < const Duration(minutes: 1)
        ? const Duration(minutes: 1)
        : planned_;
  }

  // How long until the bus reaches the next stop from where it is now.
  Duration toNext(int next) {
    if (busAt != null) {
      // Streets are about a third longer than the straight line.
      final metres =
          const Distance()(
            busAt,
            LatLng(stops[next].latitude, stops[next].longitude),
          ) *
          1.3;
      return Duration(seconds: (metres / cityMetresPerSecond).round());
    }
    if (isAtStop) return leg(next);
    final drive = next == 0 ? LiveTrip.demoDriveTime : leg(next);
    final left = drive - now.difference(leftAt!);
    if (next == 0 && !demo) {
      // No GPS yet on the way to the first stop: trust the timetable.
      final planned_ = planned[0].difference(now);
      return planned_.isNegative ? Duration.zero : planned_;
    }
    return left.isNegative ? Duration.zero : left;
  }

  // Estimates: real times for reached stops, the next one from where the
  // bus is now, then one leg after another.
  final estimates = <DateTime>[];
  DateTime? clock;
  for (var i = 0; i < stops.length; i++) {
    if (i <= reached) {
      estimates.add(reachedAt[i] ?? now);
    } else {
      clock = clock == null ? now.add(toNext(i)) : clock.add(leg(i));
      estimates.add(clock);
    }
  }

  // Position on the map: the driver's phone, else along the line. Before
  // the first stop without GPS, where the bus is isn't known.
  double? lat;
  double? lng;
  if (busAt != null) {
    lat = busAt.latitude;
    lng = busAt.longitude;
  } else if (stops.isNotEmpty && reached >= 0) {
    final fraction = isAtStop || reached + 1 >= stops.length
        ? 0.0
        : now.difference(leftAt!).inMilliseconds /
              leg(reached + 1).inMilliseconds;
    (lat, lng) = stops.length == route.stops.length
        ? positionOnTrip(route, direction, stops, reached, fraction)
        : between(stops[reached], stops[reached], 0);
  }

  return TripModel(
    direction: direction,
    phase: reached >= stops.length - 1 ? TripPhase.arrived : TripPhase.onTheWay,
    stops: stops,
    plannedTimes: planned,
    estimatedTimes: estimates,
    lastReachedIndex: reached,
    isAtStop: isAtStop,
    delayMinutes: (json['delayMinutes'] as num?)?.toInt() ?? 0,
    delayReason: json['delayReason'] as String?,
    latitude: lat,
    longitude: lng,
    isLive: true,
    boardedIds: {...(json['boardedIds'] as List).cast<String>()},
    absentIds: {...(json['absentIds'] as List).cast<String>()},
    updatedAt: now,
    road: stops.length == route.stops.length ? route.roadFor(direction) : null,
  );
}

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
