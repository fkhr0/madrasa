import '../models/bus_route_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';

enum TripBlock {
  none,

  noSchool,

  tooEarly,

  tooLate,

  alreadyDone,

  otherTripRunning,

  noStops,
}

class TripAvailability {
  final TripDirection direction;
  final TripBlock block;

  final DateTime opensAt;
  final DateTime closesAt;

  final DateTime? doneAt;

  final String? dayOffReason;

  final bool testMode;

  const TripAvailability({
    required this.direction,
    required this.block,
    required this.opensAt,
    required this.closesAt,
    this.doneAt,
    this.dayOffReason,
    this.testMode = false,
  });

  bool get isOpen => block == TripBlock.none;

  bool get canStart =>
      isOpen ||
      (testMode &&
          block != TripBlock.otherTripRunning &&
          block != TripBlock.noStops);

  bool get startsByTestMode => canStart && !isOpen;
}

TripAvailability checkTrip({
  required BusRouteModel route,
  required TripDirection direction,
  required DateTime now,
  required TransportSettingsModel settings,
  String? dayOffReason,
  DateTime? doneAt,
  TripDirection? runningTrip,
}) {
  final (opensAt, closesAt) = tripWindow(route, direction, now, settings);

  TripBlock block;
  if (route.stops.length < 2) {
    block = TripBlock.noStops;
  } else if (runningTrip != null) {
    block = TripBlock.otherTripRunning;
  } else if (dayOffReason != null) {
    block = TripBlock.noSchool;
  } else if (doneAt != null) {
    block = TripBlock.alreadyDone;
  } else if (now.isBefore(opensAt)) {
    block = TripBlock.tooEarly;
  } else if (now.isAfter(closesAt)) {
    block = TripBlock.tooLate;
  } else {
    block = TripBlock.none;
  }

  return TripAvailability(
    direction: direction,
    block: block,
    opensAt: opensAt,
    closesAt: closesAt,
    doneAt: doneAt,
    dayOffReason: dayOffReason,
    testMode: settings.testMode,
  );
}

(DateTime, DateTime) tripWindow(
  BusRouteModel route,
  TripDirection direction,
  DateTime now,
  TransportSettingsModel settings,
) {
  final day = DateTime(now.year, now.month, now.day);
  if (route.stops.isEmpty) return (day, day);

  final morning = direction == TripDirection.toSchool;
  final minutes = [
    for (final s in route.stops) morning ? s.morningMinute : s.afternoonMinute,
  ]..sort();

  return (
    day.add(Duration(minutes: minutes.first - settings.opensBeforeMinutes)),
    day.add(Duration(minutes: minutes.last + settings.closesAfterMinutes)),
  );
}

TripAvailability suggestedTrip(List<TripAvailability> trips) {
  for (final t in trips) {
    if (t.isOpen) return t;
  }
  for (final t in trips) {
    if (t.block == TripBlock.tooEarly) return t;
  }

  return trips.first;
}
