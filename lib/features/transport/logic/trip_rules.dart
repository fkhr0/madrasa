import '../models/bus_route_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';

/// Why a trip can't start right now.
enum TripBlock {
  /// It can start.
  none,

  /// Weekend, holiday or outside the study year.
  noSchool,

  /// Its time window hasn't opened yet.
  tooEarly,

  /// Its time window has closed.
  tooLate,

  /// It was already driven today.
  alreadyDone,

  /// The bus is already on a trip.
  otherTripRunning,

  /// The route has fewer than two stops.
  noStops,
}

/// Whether one of today's trips can start, and when.
/// The same rules run on the driver's screen and in the repository
/// (on the server in production), so a button can't bypass them.
class TripAvailability {
  final TripDirection direction;
  final TripBlock block;

  /// When the trip may start and must have started by.
  final DateTime opensAt;
  final DateTime closesAt;

  /// When it was finished today (for [TripBlock.alreadyDone]).
  final DateTime? doneAt;

  /// e.g. "Eid al-Fitr" or "Weekend" (for [TripBlock.noSchool]).
  final String? dayOffReason;

  /// Test mode lets the driver start it anyway.
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

  /// Test mode skips the clock and the calendar, never the safety rules
  /// (one trip at a time, a route with stops).
  bool get canStart =>
      isOpen ||
      (testMode &&
          block != TripBlock.otherTripRunning &&
          block != TripBlock.noStops);

  /// True when the trip is allowed only because of test mode.
  bool get startsByTestMode => canStart && !isOpen;
}

/// Checks one trip of [route] at [now].
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

/// Today's start window of a trip, from the route's timetable:
/// [TransportSettingsModel.opensBeforeMinutes] before the first stop until
/// [TransportSettingsModel.closesAfterMinutes] after the last one.
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

/// The trip to put first on the driver's screen: the one open now, else
/// the next one to open, else the morning trip.
TripAvailability suggestedTrip(List<TripAvailability> trips) {
  for (final t in trips) {
    if (t.isOpen) return t;
  }
  for (final t in trips) {
    if (t.block == TripBlock.tooEarly) return t;
  }

  return trips.first;
}
