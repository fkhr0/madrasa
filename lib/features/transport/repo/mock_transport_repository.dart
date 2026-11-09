import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../core/utils/location_link.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/data/mock_users.dart';
import '../../notifications/data/demo_notifier.dart';
import '../../notifications/models/notification_model.dart';
import '../data/mock_transport.dart';
import '../data/trip_simulator.dart';
import '../logic/trip_rules.dart';
import '../logic/trip_text.dart';
import '../models/bus_route_model.dart';
import '../models/place_model.dart';
import '../models/route_student_model.dart';
import '../models/student_home_model.dart';
import '../models/student_transport_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';
import 'live_trip.dart';
import 'transport_repository.dart';

/// TEST MODE.
class MockTransportRepository implements TransportRepository {
  /// Why there is no school on a date ("Weekend", "Eid al-Fitr"...),
  /// or null on school days. Buses only run on school days.
  final String? Function(DateTime day) dayOffReason;
  final DemoNotifier notifier;

  MockTransportRepository({required this.dayOffReason, required this.notifier});

  /// Told about every trip start, delay and early end.
  static final _officeIds = [MockUsers.admin.id];

  final Map<String, BusRouteModel> _routes = {
    for (final route in MockTransport.routes) route.id: route,
  };

  final Map<String, List<RouteStudentModel>> _rosters = {
    for (final route in MockTransport.routes)
      route.id: MockTransport.rosterOf(route.id),
  };

  TransportSettingsModel _settings = const TransportSettingsModel();

  /// Route ID → trips finished on [_finishedDay].
  final Map<String, Map<TripDirection, DateTime>> _finished = {};
  DateTime? _finishedDay;
  int _routeCount = 0;

  /// Route ID → the trip the driver is running.
  final Map<String, LiveTrip> _live = {};

  /// Route ID → open trip streams.
  final Map<String, Set<StreamController<TripModel>>> _listeners = {};
  Timer? _ticker;
  int _notificationCount = 0;

  // ---------- Reading ----------

  @override
  Future<StudentTransportModel?> getStudentTransport(String studentId) async {
    for (final route in _routes.values) {
      for (final student in _rosters[route.id]!) {
        if (student.id == studentId) {
          return StudentTransportModel(
            route: _withCount(route),
            stopId: student.stopId,
            notRidingToday: student.notRidingToday,
          );
        }
      }
    }

    return null;
  }

  @override
  Future<BusRouteModel?> getRoute(String routeId) async {
    final route = _routes[routeId];
    return route == null ? null : _withCount(route);
  }

  @override
  Future<List<RouteStudentModel>> getRouteStudents(String routeId) async {
    final route = await getRoute(routeId);
    final order = [for (final s in route?.stops ?? const []) s.id];

    return [...?_rosters[routeId]]..sort(
      (a, b) => order.indexOf(a.stopId).compareTo(order.indexOf(b.stopId)),
    );
  }

  @override
  Future<List<BusRouteModel>> getRoutes() async =>
      _routes.values.map(_withCount).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<BusRouteModel?> getDriverRoute(String driverId) async {
    for (final route in _routes.values) {
      if (route.driverId == driverId) return _withCount(route);
    }

    return null;
  }

  @override
  Future<TransportSettingsModel> getSettings() async => _settings;

  @override
  Future<Map<TripDirection, DateTime>> getFinishedTrips(String routeId) async =>
      {..._finishedToday(routeId)};

  @override
  Stream<TripModel> watchTrip(String routeId) {
    late final StreamController<TripModel> controller;

    controller = StreamController<TripModel>(
      onListen: () {
        _listeners.putIfAbsent(routeId, () => {}).add(controller);
        controller.add(_current(routeId));
        _ensureTicker();
      },
      onCancel: () {
        _listeners[routeId]?.remove(controller);
        _stopTickerIfIdle();
      },
    );

    return controller.stream;
  }

  // ---------- Parent ----------

  @override
  Future<void> setNotRidingToday(String studentId, bool notRiding) async {
    for (final route in _routes.values) {
      final roster = _rosters[route.id]!;
      final index = roster.indexWhere((s) => s.id == studentId);
      if (index == -1) continue;

      final student = roster[index].copyWith(notRidingToday: notRiding);
      roster[index] = student;

      _notify(
        [route.driverId],
        route: AppRoutes.home,
        title: notRiding
            ? '${student.name} won\'t ride today'
            : '${student.name} will ride today',
        body: 'Told by ${student.parentName}',
      );
      _emit(route.id);
    }
  }

  // ---------- Driver ----------

  @override
  Future<void> startTrip(String routeId, TripDirection direction) async {
    final route = (await getRoute(routeId))!;
    final now = DateTime.now();

    // The same rules as the driver's screen: a button can't bypass them.
    final check = checkTrip(
      route: route,
      direction: direction,
      now: now,
      settings: _settings,
      dayOffReason: dayOffReason(now),
      doneAt: _finishedToday(routeId)[direction],
      runningTrip: _live[routeId]?.direction,
    );
    if (!check.canStart) {
      throw TransportException(tripAvailabilityText(check, now));
    }

    final trip = LiveTrip.start(route, direction, now);
    _live[routeId] = trip;

    final started =
        'Bus ${route.busNumber} started the ${direction.label.toLowerCase()}';
    _notify(
      _ridersAndParents(routeId),
      title: started,
      body: 'Follow it live in the app',
    );
    _notifyOffice(routeId, title: started, body: route.driverName);
    _ensureTicker();
    _emit(routeId);
  }

  @override
  Future<void> leaveStop(String routeId) async {
    final trip = _live[routeId];
    if (trip == null || !trip.isAtStop) return;

    trip.leave(DateTime.now());

    // Tell the next stop the bus is coming.
    final next = trip.stops[trip.reachedIndex + 1];
    _notify(
      _ridersAndParents(routeId, stopId: next.id),
      title: 'Bus ${trip.route.busNumber} is on its way',
      body: 'Next stop: ${next.name}',
    );
    _emit(routeId);
  }

  @override
  Future<void> arriveAtStop(String routeId) async {
    final trip = _live[routeId];
    if (trip == null || trip.isAtStop) return;

    final index = trip.arriveNow(DateTime.now());
    _onArrived(routeId, trip, index);
    _emit(routeId);
  }

  /// Test mode drives the bus itself; GPS points are not needed.
  @override
  Future<void> sendLocation(
    String routeId,
    double latitude,
    double longitude, {
    double? accuracy,
  }) async {}

  @override
  Future<void> setBoarding(
    String routeId,
    String studentId,
    BoardingStatus status,
  ) async {
    final trip = _live[routeId];
    if (trip == null) return;

    trip.boarded.remove(studentId);
    trip.absent.remove(studentId);
    if (status == BoardingStatus.onBoard) trip.boarded.add(studentId);
    if (status == BoardingStatus.absent) trip.absent.add(studentId);

    final student = _rosters[routeId]!.firstWhere((s) => s.id == studentId);
    final bus = trip.route.busNumber;

    if (status == BoardingStatus.onBoard) {
      _notify(
        [student.id, student.parentId],
        title: '${student.name} is on bus $bus',
        body: 'Boarded at ${trip.stops[trip.reachedIndex].name}',
      );
    } else if (status == BoardingStatus.absent) {
      _notify(
        [student.parentId],
        title: '${student.name} was not at the bus stop',
        body:
            'Bus $bus left ${trip.stops[trip.reachedIndex].name} without them',
      );
    }
    _emit(routeId);
  }

  @override
  Future<void> reportDelay(String routeId, int minutes, String reason) async {
    final trip = _live[routeId];
    if (trip == null) return;

    trip.delayMinutes += minutes;
    trip.delayReason = reason;

    final late =
        'Bus ${trip.route.busNumber} is running ${trip.delayMinutes} min late';
    _notify(_ridersAndParents(routeId), title: late, body: reason);
    _notifyOffice(routeId, title: late, body: reason);
    _emit(routeId);
  }

  @override
  Future<void> endTrip(String routeId, {String? earlyReason}) async {
    final trip = _live.remove(routeId);
    if (trip == null) return;

    _finishedToday(routeId)[trip.direction] = DateTime.now();

    if (earlyReason != null) {
      final ended =
          'Bus ${trip.route.busNumber} ended the '
          '${trip.direction.label.toLowerCase()} early';
      _notify(
        _ridersAndParents(routeId),
        title: ended,
        body: '$earlyReason · the school will contact you',
      );
      _notifyOffice(
        routeId,
        title: ended,
        body: '$earlyReason · please contact the families',
      );
    }
    _emit(routeId);
  }

  // ---------- Administrator ----------

  @override
  Future<BusRouteModel> saveRoute(BusRouteModel route) async {
    var saved = route;

    if (route.id.isEmpty) {
      saved = BusRouteModel(
        id: 'route-new-${++_routeCount}',
        name: route.name,
        busNumber: route.busNumber,
        plateNumber: route.plateNumber,
        driverId: route.driverId,
        driverName: route.driverName,
        driverPhone: route.driverPhone,
        supervisorName: route.supervisorName,
        supervisorPhone: route.supervisorPhone,
        // Every line ends at the school.
        stops: route.stops.isEmpty ? [MockTransport.school] : route.stops,
        capacity: route.capacity,
      );
      _rosters[saved.id] = [];
    }

    // A driver drives one bus: take them off any other line.
    if (saved.hasDriver) {
      for (final other in _routes.values.toList()) {
        if (other.id != saved.id && other.driverId == saved.driverId) {
          _routes[other.id] = other.copyWith(
            driverId: '',
            driverName: '',
            driverPhone: '',
          );
        }
      }
    }

    _routes[saved.id] = saved;

    // Students of a stop that was removed come off the line.
    final stopIds = {for (final s in saved.stops) s.id};
    _rosters[saved.id]!.removeWhere((s) => !stopIds.contains(s.stopId));

    _emit(saved.id);
    return _withCount(saved);
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    if (_live.containsKey(routeId)) {
      throw const TransportException(
        'The bus is on a trip. Delete the line after the trip ends.',
      );
    }
    _routes.remove(routeId);
    _rosters.remove(routeId);
  }

  @override
  Future<void> saveRouteStudent(
    String routeId,
    RouteStudentModel student,
  ) async {
    final roster = _rosters[routeId]!;
    final index = roster.indexWhere((s) => s.id == student.id);

    if (index != -1) {
      roster[index] = student;
    } else {
      final route = _routes[routeId]!;
      if (roster.length >= route.capacity) {
        throw TransportException(
          'Bus ${route.busNumber} is full (${route.capacity} seats).',
        );
      }

      // A student rides one bus: take them off the old one.
      for (final other in _rosters.values) {
        other.removeWhere((s) => s.id == student.id);
      }
      roster.add(student);
    }
    _emit(routeId);
  }

  @override
  Future<void> removeRouteStudent(String routeId, String studentId) async {
    _rosters[routeId]?.removeWhere((s) => s.id == studentId);
    _emit(routeId);
  }

  @override
  Future<void> saveSettings(TransportSettingsModel settings) async {
    _settings = settings;
  }

  /// Test mode has no internet search: a few well-known Baghdad places.
  @override
  Future<List<PlaceModel>> searchPlaces(String text) async {
    const places = [
      PlaceModel(
        name: 'Al-Yarmouk Hospital',
        address: 'Al-Yarmouk, Baghdad',
        latitude: 33.2948,
        longitude: 44.3536,
      ),
      PlaceModel(
        name: 'Al-Zawraa Park',
        address: 'Al-Mansour, Baghdad',
        latitude: 33.3125,
        longitude: 44.3720,
      ),
      PlaceModel(
        name: 'Tahrir Square',
        address: 'Al-Rusafa, Baghdad',
        latitude: 33.3285,
        longitude: 44.4146,
      ),
    ];
    final q = text.toLowerCase();
    return places.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  final Map<String, StudentHomeModel> _homes = {};

  @override
  Future<StudentHomeModel?> getStudentHome(String studentId) async =>
      _homes[studentId];

  @override
  Future<void> saveStudentHome(String studentId, StudentHomeModel home) async {
    if (!IraqMap.contains(home.point)) {
      throw const TransportException('That place is outside Iraq.');
    }
    _homes[studentId] = home;
  }

  /// Test mode can't follow short links; full links and numbers work.
  @override
  Future<LatLng> readLocation(String text) async {
    final found = coordinatesIn(text);
    if (found == null || !IraqMap.contains(found)) {
      throw const TransportException(
        'No place in Iraq found in that. Paste the location link from '
        'WhatsApp or Google Maps.',
      );
    }
    return found;
  }

  // ---------- Engine ----------

  TripModel _current(String routeId) {
    final now = DateTime.now();
    final live = _live[routeId];
    if (live != null) return live.toModel(now);

    final route = _routes[routeId];
    if (route == null) return TripModel.none(updatedAt: now);

    return simulateTrip(
      route: route,
      now: now,
      isSchoolDay: dayOffReason(now) == null,
    );
  }

  BusRouteModel _withCount(BusRouteModel route) =>
      route.copyWith(studentCount: _rosters[route.id]?.length ?? 0);

  /// Today's finished trips of a route (cleared when the day changes).
  Map<TripDirection, DateTime> _finishedToday(String routeId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_finishedDay != today) {
      _finished.clear();
      _finishedDay = today;
    }

    return _finished.putIfAbsent(routeId, () => {});
  }

  /// One shared clock: moves live buses and refreshes every open stream.
  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTickerIfIdle() {
    final hasListeners = _listeners.values.any((set) => set.isNotEmpty);
    final busMoving = _live.values.any((t) => !t.isAtStop);

    if (!hasListeners && !busMoving) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    final now = DateTime.now();

    for (final entry in _live.entries) {
      final arrivedAt = entry.value.advance(now);
      if (arrivedAt != null) _onArrived(entry.key, entry.value, arrivedAt);
    }

    for (final routeId in _listeners.keys) {
      _emit(routeId);
    }
    _stopTickerIfIdle();
  }

  void _onArrived(String routeId, LiveTrip trip, int index) {
    final stop = trip.stops[index];
    final bus = trip.route.busNumber;
    final isLast = index == trip.stops.length - 1;
    final roster = _rosters[routeId]!;

    if (trip.direction == TripDirection.toSchool) {
      if (isLast) {
        for (final s in roster.where((s) => trip.boarded.contains(s.id))) {
          _notify(
            [s.parentId],
            title: '${s.name} arrived at school',
            body: 'Bus $bus reached ${stop.name}',
          );
        }
      } else {
        _notify(
          _ridersAndParents(routeId, stopId: stop.id),
          title: 'Bus $bus is at ${stop.name}',
          body: 'Please be at the stop',
        );
      }
    } else {
      for (final s in roster.where(
        (s) => s.stopId == stop.id && !s.notRidingToday,
      )) {
        _notify(
          [s.id, s.parentId],
          title: '${s.name} was dropped off',
          body: 'Bus $bus at ${stop.name}',
        );
      }
    }
  }

  void _emit(String routeId) {
    final listeners = _listeners[routeId];
    if (listeners == null || listeners.isEmpty) return;

    final trip = _current(routeId);
    for (final controller in listeners) {
      controller.add(trip);
    }
  }

  /// Students riding today (optionally only one stop) and their parents.
  List<String> _ridersAndParents(String routeId, {String? stopId}) {
    return [
      for (final s in _rosters[routeId]!)
        if (!s.notRidingToday && (stopId == null || s.stopId == stopId)) ...[
          s.id,
          s.parentId,
        ],
    ];
  }

  /// The school office gets the same news, opening the line's page.
  void _notifyOffice(
    String routeId, {
    required String title,
    required String body,
  }) => _notify(
    _officeIds,
    title: title,
    body: body,
    route: AppRoutes.busRoute(routeId),
  );

  void _notify(
    List<String> userIds, {
    required String title,
    required String body,
    String route = AppRoutes.bus,
  }) {
    if (userIds.isEmpty) return;

    notifier.notify(
      userIds,
      NotificationModel(
        id: 'live-${++_notificationCount}',
        type: NotificationType.transport,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        route: route,
      ),
    );
  }
}
