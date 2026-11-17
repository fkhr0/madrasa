import '../data/trip_simulator.dart';
import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/trip_model.dart';

class LiveTrip {
  static const demoDriveTime = Duration(seconds: 20);

  final BusRouteModel route;
  final TripDirection direction;

  final List<BusStopModel> stops;
  final List<DateTime> plannedTimes;

  final List<DateTime?> reachedAt;

  int reachedIndex = 0;
  bool isAtStop = true;
  DateTime? leftStopAt;

  int delayMinutes = 0;
  String? delayReason;

  final Set<String> boarded = {};
  final Set<String> absent = {};

  LiveTrip._(this.route, this.direction, this.stops, this.plannedTimes)
    : reachedAt = List.filled(stops.length, null);

  factory LiveTrip.start(
    BusRouteModel route,
    TripDirection direction,
    DateTime now,
  ) {
    final toSchool = direction == TripDirection.toSchool;
    final stops = toSchool ? route.stops : route.stops.reversed.toList();
    final day = DateTime(now.year, now.month, now.day);

    final trip = LiveTrip._(route, direction, stops, [
      for (final s in stops)
        day.add(
          Duration(minutes: toSchool ? s.morningMinute : s.afternoonMinute),
        ),
    ]);
    trip.reachedAt[0] = now;

    return trip;
  }

  void leave(DateTime now) {
    isAtStop = false;
    leftStopAt = now;
  }

  int? advance(DateTime now) {
    if (isAtStop || leftStopAt == null) return null;
    if (now.difference(leftStopAt!) < demoDriveTime) return null;

    return arriveNow(now);
  }

  int arriveNow(DateTime now) {
    reachedIndex++;
    reachedAt[reachedIndex] = now;
    isAtStop = true;
    leftStopAt = null;

    return reachedIndex;
  }

  TripModel toModel(DateTime now) {
    final fraction = isAtStop
        ? 0.0
        : now.difference(leftStopAt!).inMilliseconds /
              demoDriveTime.inMilliseconds;
    final (lat, lng) = positionOnTrip(
      route,
      direction,
      stops,
      reachedIndex,
      fraction,
    );

    final departure = isAtStop ? now : leftStopAt!;
    final estimates = [
      for (var i = 0; i < stops.length; i++)
        reachedAt[i] ?? departure.add(demoDriveTime * (i - reachedIndex)),
    ];

    final finished = reachedIndex == stops.length - 1;

    return TripModel(
      direction: direction,
      phase: finished ? TripPhase.arrived : TripPhase.onTheWay,
      stops: stops,
      plannedTimes: plannedTimes,
      estimatedTimes: estimates,
      lastReachedIndex: reachedIndex,
      isAtStop: isAtStop,
      delayMinutes: delayMinutes,
      delayReason: delayReason,
      latitude: lat,
      longitude: lng,
      isLive: true,
      boardedIds: {...boarded},
      absentIds: {...absent},
      updatedAt: now,
      road: route.roadFor(direction),
    );
  }
}
