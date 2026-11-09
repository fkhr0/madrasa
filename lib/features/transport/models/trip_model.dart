import 'bus_stop_model.dart';
import 'road_path_model.dart';
import 'route_student_model.dart';
import '../../../core/l10n/language.dart';

enum TripDirection {
  toSchool,
  toHome;

  String get label {
    switch (this) {
      case TripDirection.toSchool:
        return tr('Morning trip');
      case TripDirection.toHome:
        return tr('Afternoon trip');
    }
  }
}

enum TripPhase {
  /// Weekend, holiday, or the school has no trips today.
  noTripToday,

  /// The bus has not left the first stop yet.
  notStarted,
  onTheWay,
  arrived,
}

/// A bus trip as it is right now.
class TripModel {
  final TripDirection direction;
  final TripPhase phase;

  /// Stops in the order this trip visits them.
  final List<BusStopModel> stops;

  /// Planned time at each stop (same order as [stops]).
  final List<DateTime> plannedTimes;

  /// Live estimates, when the driver is reporting (same order as [stops]).
  final List<DateTime>? estimatedTimes;

  /// Index of the last stop the bus reached (-1 before the first).
  final int lastReachedIndex;

  /// True while the bus is standing at stops[lastReachedIndex].
  final bool isAtStop;

  /// Minutes behind the plan, as reported by the driver.
  final int delayMinutes;
  final String? delayReason;

  /// Current position (for the map), when known.
  final double? latitude;
  final double? longitude;

  /// True when the driver is reporting this trip.
  final bool isLive;

  /// Student IDs the driver marked on board / absent on this trip.
  final Set<String> boardedIds;
  final Set<String> absentIds;

  final DateTime updatedAt;

  /// The streets of this trip (null: straight lines between stops).
  final RoadPathModel? road;

  const TripModel({
    required this.direction,
    required this.phase,
    required this.stops,
    required this.plannedTimes,
    required this.lastReachedIndex,
    required this.updatedAt,
    this.estimatedTimes,
    this.isAtStop = false,
    this.delayMinutes = 0,
    this.delayReason,
    this.latitude,
    this.longitude,
    this.isLive = false,
    this.boardedIds = const {},
    this.absentIds = const {},
    this.road,
  });

  const TripModel.none({required this.updatedAt})
    : direction = TripDirection.toSchool,
      phase = TripPhase.noTripToday,
      stops = const [],
      plannedTimes = const [],
      estimatedTimes = null,
      lastReachedIndex = -1,
      isAtStop = false,
      delayMinutes = 0,
      delayReason = null,
      latitude = null,
      longitude = null,
      isLive = false,
      boardedIds = const {},
      absentIds = const {},
      road = null;

  bool get hasPosition => latitude != null && longitude != null;

  int indexOf(String stopId) => stops.indexWhere((s) => s.id == stopId);

  /// Best known time at a stop: the live estimate, else plan + delay.
  DateTime expectedAt(int index) =>
      estimatedTimes?[index] ??
      plannedTimes[index].add(Duration(minutes: delayMinutes));

  bool hasPassed(int index) => index <= lastReachedIndex;

  /// The stop the bus is driving to, or null at the end.
  int? get nextStopIndex =>
      lastReachedIndex + 1 < stops.length ? lastReachedIndex + 1 : null;

  /// 0–1: how much of the route is done.
  double get progress => stops.length < 2
      ? 0
      : (lastReachedIndex / (stops.length - 1)).clamp(0, 1);

  /// Minutes until the bus reaches [index] (0 if it is due now).
  int minutesUntil(int index, DateTime now) {
    final minutes = expectedAt(index).difference(now).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  /// Where [student] is on this trip.
  BoardingStatus statusOf(RouteStudentModel student) => statusFor(
    studentId: student.id,
    stopId: student.stopId,
    notRidingToday: student.notRidingToday,
  );

  BoardingStatus statusFor({
    required String studentId,
    required String stopId,
    bool notRidingToday = false,
  }) {
    if (notRidingToday) return BoardingStatus.notRiding;
    if (absentIds.contains(studentId)) return BoardingStatus.absent;

    if (direction == TripDirection.toHome) {
      // Everyone boards at school; they are "dropped off" once their stop
      // has been reached.
      final stopIndex = indexOf(stopId);
      if (stopIndex != -1 && hasPassed(stopIndex) && stopIndex > 0) {
        return BoardingStatus.droppedOff;
      }
    }

    if (boardedIds.contains(studentId)) {
      return phase == TripPhase.arrived && direction == TripDirection.toSchool
          ? BoardingStatus.droppedOff
          : BoardingStatus.onBoard;
    }

    return BoardingStatus.waiting;
  }
}
