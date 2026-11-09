import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../realtime/providers/realtime_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/providers/clock_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../people/providers/people_provider.dart';
import '../logic/trip_rules.dart';
import '../models/bus_route_model.dart';
import '../models/place_model.dart';
import '../models/route_student_model.dart';
import '../models/student_home_model.dart';
import '../models/student_transport_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';
import '../repo/api_transport_repository.dart';
import '../repo/mock_transport_repository.dart';
import '../repo/transport_repository.dart';

/// The school server when API_URL is set, otherwise test mode on this device.
final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  String? dayOffReason(DateTime day) =>
      ref.read(academicYearProvider).valueOrNull?.dayOffReason(day);

  return AppConfig.useApi
      ? ApiTransportRepository(
          watchApi(ref),
          dayOffReason: dayOffReason,
          realtime: ref.watch(realtimeClientProvider),
        )
      : MockTransportRepository(
          dayOffReason: dayOffReason,
          notifier: ref.read(demoNotifierProvider),
        );
});

/// The active student's bus (the student themself, or the parent's child).
final myTransportProvider = FutureProvider<StudentTransportModel?>(
  (ref) => ref
      .watch(transportRepositoryProvider)
      .getStudentTransport(ref.watch(activeStudentIdProvider)),
);

/// Live trip of a route.
final tripProvider = StreamProvider.family<TripModel, String>(
  (ref, routeId) => ref.watch(transportRepositoryProvider).watchTrip(routeId),
);

final busRoutesProvider = FutureProvider<List<BusRouteModel>>(
  (ref) => ref.watch(transportRepositoryProvider).getRoutes(),
);

final busRouteProvider = FutureProvider.family<BusRouteModel?, String>(
  (ref, routeId) => ref.watch(transportRepositoryProvider).getRoute(routeId),
);

final routeStudentsProvider =
    FutureProvider.family<List<RouteStudentModel>, String>(
      (ref, routeId) =>
          ref.watch(transportRepositoryProvider).getRouteStudents(routeId),
    );

/// The signed-in driver's line (null when none is assigned).
final driverRouteProvider = FutureProvider<BusRouteModel?>(
  (ref) => ref
      .watch(transportRepositoryProvider)
      .getDriverRoute(ref.watch(currentUserProvider).id),
);

final transportSettingsProvider = FutureProvider<TransportSettingsModel>(
  (ref) => ref.watch(transportRepositoryProvider).getSettings(),
);

final finishedTripsProvider =
    FutureProvider.family<Map<TripDirection, DateTime>, String>(
      (ref, routeId) =>
          ref.watch(transportRepositoryProvider).getFinishedTrips(routeId),
    );

/// Morning and afternoon trip of a route: can they start now, and when.
/// Empty while loading.
final tripAvailabilityProvider =
    Provider.family<List<TripAvailability>, String>((ref, routeId) {
      final route = ref.watch(busRouteProvider(routeId)).valueOrNull;
      final settings = ref.watch(transportSettingsProvider).valueOrNull;
      final finished = ref.watch(finishedTripsProvider(routeId)).valueOrNull;
      final trip = ref.watch(tripProvider(routeId)).valueOrNull;
      final year = ref.watch(academicYearProvider).valueOrNull;
      final DateTime now = ref.watch(nowProvider);

      if (route == null || settings == null || finished == null) return [];

      return [
        for (final direction in TripDirection.values)
          checkTrip(
            route: route,
            direction: direction,
            now: now,
            settings: settings,
            dayOffReason: year?.dayOffReason(now),
            doneAt: finished[direction],
            runningTrip: trip != null && trip.isLive ? trip.direction : null,
          ),
      ];
    });

/// Every student registered on any bus, by student ID → route ID.
final busRidersProvider = FutureProvider<Map<String, String>>((ref) async {
  final routes = await ref.watch(busRoutesProvider.future);
  final repository = ref.watch(transportRepositoryProvider);

  return {
    for (final route in routes)
      for (final s in await repository.getRouteStudents(route.id))
        s.id: route.id,
  };
});

/// Students of the school who are not on any bus yet.
final studentsWithoutBusProvider = FutureProvider<List<UserModel>>((ref) async {
  final riders = await ref.watch(busRidersProvider.future);
  final students = await ref.watch(
    peopleByRoleProvider(UserRole.student).future,
  );

  return students.where((s) => !riders.containsKey(s.id)).toList();
});

/// Where a student lives (door-to-door pick-up), or null.
final studentHomeProvider = FutureProvider.family<StudentHomeModel?, String>(
  (ref, studentId) =>
      ref.watch(transportRepositoryProvider).getStudentHome(studentId),
);

final transportActionsProvider = Provider<TransportActions>(
  TransportActions.new,
);

/// What drivers, parents and administrators can change. Trip screens update
/// by themselves through [tripProvider]; everything else is reloaded here.
class TransportActions {
  final Ref _ref;

  TransportActions(this._ref);

  TransportRepository get _repository => _ref.read(transportRepositoryProvider);

  // ---------- Driver ----------
  /// Throws [TransportException] when the trip rules don't allow it.
  Future<void> startTrip(String routeId, TripDirection direction) =>
      _repository.startTrip(routeId, direction);

  Future<void> leaveStop(String routeId) => _repository.leaveStop(routeId);

  Future<void> arriveAtStop(String routeId) =>
      _repository.arriveAtStop(routeId);

  Future<void> sendLocation(
    String routeId,
    double lat,
    double lng, {
    double? accuracy,
  }) => _repository.sendLocation(routeId, lat, lng, accuracy: accuracy);

  Future<void> setBoarding(
    String routeId,
    String studentId,
    BoardingStatus status,
  ) => _repository.setBoarding(routeId, studentId, status);

  Future<void> reportDelay(String routeId, int minutes, String reason) =>
      _repository.reportDelay(routeId, minutes, reason);

  Future<void> endTrip(String routeId, {String? earlyReason}) async {
    await _repository.endTrip(routeId, earlyReason: earlyReason);
    _ref.invalidate(finishedTripsProvider(routeId));
  }

  // ---------- Parent ----------
  Future<void> setNotRidingToday(String studentId, bool notRiding) async {
    await _repository.setNotRidingToday(studentId, notRiding);
    _ref
      ..invalidate(myTransportProvider)
      ..invalidate(routeStudentsProvider);
  }

  // ---------- Administrator ----------
  Future<BusRouteModel> saveRoute(BusRouteModel route) async {
    final saved = await _repository.saveRoute(route);
    _reloadRoutes();
    return saved;
  }

  /// Throws [TransportException] while the bus is on a trip.
  Future<void> deleteRoute(String routeId) async {
    await _repository.deleteRoute(routeId);
    _reloadRoutes();
  }

  /// Throws [TransportException] when the bus is full.
  Future<void> saveRouteStudent(
    String routeId,
    RouteStudentModel student,
  ) async {
    await _repository.saveRouteStudent(routeId, student);
    _reloadRoutes();
  }

  Future<void> removeRouteStudent(String routeId, String studentId) async {
    await _repository.removeRouteStudent(routeId, studentId);
    _reloadRoutes();
  }

  Future<List<PlaceModel>> searchPlaces(String text) =>
      _repository.searchPlaces(text);

  Future<LatLng> readLocation(String text) => _repository.readLocation(text);

  Future<void> saveStudentHome(String studentId, StudentHomeModel home) async {
    await _repository.saveStudentHome(studentId, home);
    _ref.invalidate(studentHomeProvider(studentId));
  }

  Future<void> saveSettings(TransportSettingsModel settings) async {
    await _repository.saveSettings(settings);
    _ref.invalidate(transportSettingsProvider);
  }

  void _reloadRoutes() {
    _ref
      ..invalidate(busRoutesProvider)
      ..invalidate(busRouteProvider)
      ..invalidate(routeStudentsProvider)
      ..invalidate(driverRouteProvider)
      ..invalidate(myTransportProvider)
      ..invalidate(busRidersProvider);
  }
}
