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

enum TripPhase { noTripToday, notStarted, onTheWay, arrived }

class TripModel {
  final TripDirection direction;
  final TripPhase phase;

  final List<BusStopModel> stops;

  final List<DateTime> plannedTimes;

  final List<DateTime>? estimatedTimes;

  final int lastReachedIndex;

  final bool isAtStop;

  final int delayMinutes;
  final String? delayReason;

  final double? latitude;
  final double? longitude;

  final bool isLive;

  final Set<String> boardedIds;
  final Set<String> absentIds;

  final DateTime updatedAt;

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

  DateTime expectedAt(int index) =>
      estimatedTimes?[index] ??
      plannedTimes[index].add(Duration(minutes: delayMinutes));

  bool hasPassed(int index) => index <= lastReachedIndex;

  int? get nextStopIndex =>
      lastReachedIndex + 1 < stops.length ? lastReachedIndex + 1 : null;

  double get progress => stops.length < 2
      ? 0
      : (lastReachedIndex / (stops.length - 1)).clamp(0, 1);

  int minutesUntil(int index, DateTime now) {
    final minutes = expectedAt(index).difference(now).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

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
