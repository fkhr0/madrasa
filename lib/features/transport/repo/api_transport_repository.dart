import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/realtime_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/trip_simulator.dart';
import '../logic/server_trip.dart';
import '../models/bus_route_model.dart';
import '../models/place_model.dart';
import '../models/route_student_model.dart';
import '../models/student_home_model.dart';
import '../models/student_transport_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';
import 'transport_repository.dart';

/// School buses on the school API (server/src/features/transport).
class ApiTransportRepository implements TransportRepository {
  final ApiClient _api;

  /// Why there is no school on a date, or null on school days.
  final String? Function(DateTime day) dayOffReason;

  /// The live connection: the trip reloads the moment it changes.
  final RealtimeClient? realtime;

  ApiTransportRepository(
    this._api, {
    required this.dayOffReason,
    this.realtime,
  });

  /// Without the live connection. With it, the trip still reloads every
  /// [backupEvery], in case an update was missed.
  static const refreshEvery = Duration(seconds: 3);
  static const backupEvery = Duration(seconds: 15);

  // ---------- Reading ----------

  @override
  Future<StudentTransportModel?> getStudentTransport(String studentId) async {
    final json = await _api.get('/transport/students/$studentId');
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return StudentTransportModel(
      route: BusRouteModel.fromJson(map['route'] as Map<String, dynamic>),
      stopId: map['stopId'] as String,
      notRidingToday: map['notRidingToday'] as bool? ?? false,
    );
  }

  @override
  Future<BusRouteModel?> getRoute(String routeId) async {
    try {
      return BusRouteModel.fromJson(
        await _api.get('/transport/routes/$routeId') as Map<String, dynamic>,
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<RouteStudentModel>> getRouteStudents(String routeId) async {
    final list = await _api.get('/transport/routes/$routeId/students') as List;
    return [
      for (final json in list)
        RouteStudentModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<BusRouteModel>> getRoutes() async {
    final list = await _api.get('/transport/routes') as List;
    return [
      for (final json in list)
        BusRouteModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<BusRouteModel?> getDriverRoute(String driverId) async {
    // The server knows the signed-in driver.
    final json = await _api.get('/transport/driver-route');
    return json == null
        ? null
        : BusRouteModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<TransportSettingsModel> getSettings() async =>
      TransportSettingsModel.fromJson(
        await _api.get('/transport/settings') as Map<String, dynamic>,
      );

  @override
  Future<Map<TripDirection, DateTime>> getFinishedTrips(String routeId) async {
    final json =
        await _api.get('/transport/routes/$routeId/trip')
            as Map<String, dynamic>;
    return _finished(json);
  }

  static Map<TripDirection, DateTime> _finished(Map<String, dynamic> json) => {
    for (final entry in (json['finished'] as Map<String, dynamic>).entries)
      TripDirection.values.byName(entry.key): DateTime.parse(
        entry.value as String,
      ).toLocal(),
  };

  @override
  Stream<TripModel> watchTrip(String routeId) {
    late final StreamController<TripModel> controller;
    Timer? redraw;
    Timer? refresh;
    BusRouteModel? route;
    var settings = const TransportSettingsModel();
    Map<String, dynamic>? running;
    var loaded = false;
    var loads = 0;
    // How far the server's clock is from this phone's. A phone a few
    // minutes off would otherwise see a live bus as "last seen", or move it
    // along the line at the wrong place.
    var clockOffset = Duration.zero;

    void emit() {
      if (!loaded || controller.isClosed) return;
      final now = DateTime.now().add(clockOffset);
      final r = route;
      if (r == null) {
        controller.add(TripModel.none(updatedAt: now));
      } else if (running case final trip?) {
        controller.add(
          tripFromServer(
            route: r,
            json: trip,
            now: now,
            testMode: settings.testMode,
          ),
        );
      } else {
        // No driver reporting: follow the timetable.
        controller.add(
          simulateTrip(
            route: r,
            now: now,
            isSchoolDay: dayOffReason(now) == null,
          ),
        );
      }
    }

    Future<void> load() async {
      try {
        // The line changes rarely: ask again every fifth time (15 s), so
        // new stops and roads reach every map without a reload.
        if (route == null || loads % 5 == 0) route = await getRoute(routeId);
        loads++;
        if (!loaded) settings = await getSettings();
        final asked = DateTime.now();
        final json =
            await _api.get('/transport/routes/$routeId/trip')
                as Map<String, dynamic>;
        // The server read its clock about halfway through the request.
        // (Not from a copy saved while offline: that clock is old.)
        if (json['serverTime'] case final String serverTime
            when !_api.offline.value) {
          final halfway = asked.add(DateTime.now().difference(asked) ~/ 2);
          clockOffset = DateTime.parse(serverTime).difference(halfway);
        }
        running = json['trip'] as Map<String, dynamic>?;
        loaded = true;
        emit();
      } on ApiException catch (e) {
        // Keep showing the last trip; report only if nothing came yet.
        if (!loaded && !controller.isClosed) controller.addError(e);
      }
    }

    var lastLoad = DateTime.now();
    Future<void> reload() {
      lastLoad = DateTime.now();
      return load();
    }

    StreamSubscription<RealtimeEvent>? live;
    controller = StreamController<TripModel>(
      onListen: () {
        reload();
        live = realtime?.events
            .where((e) => e.type == 'trip.updated' && e['routeId'] == routeId)
            .listen((_) => reload());
        refresh = Timer.periodic(refreshEvery, (_) {
          final connected = realtime?.isConnected ?? false;
          if (connected && DateTime.now().difference(lastLoad) < backupEvery) {
            return;
          }
          reload();
        });
        redraw = Timer.periodic(const Duration(seconds: 1), (_) => emit());
      },
      onCancel: () {
        refresh?.cancel();
        redraw?.cancel();
        live?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  // ---------- Parent ----------

  @override
  Future<void> setNotRidingToday(String studentId, bool notRiding) => _act(
    () => _api.post('/transport/students/$studentId/not-riding', {
      'notRiding': notRiding,
    }),
  );

  // ---------- Driver ----------

  @override
  Future<void> startTrip(String routeId, TripDirection direction) => _act(
    () => _api.post('/transport/routes/$routeId/trip/start', {
      'direction': direction.name,
    }),
  );

  @override
  Future<void> leaveStop(String routeId) =>
      _act(() => _api.post('/transport/routes/$routeId/trip/leave', {}));

  @override
  Future<void> arriveAtStop(String routeId) =>
      _act(() => _api.post('/transport/routes/$routeId/trip/arrive', {}));

  @override
  Future<void> sendLocation(
    String routeId,
    double latitude,
    double longitude, {
    double? accuracy,
  }) => _act(
    () => _api.post('/transport/routes/$routeId/trip/location', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': ?accuracy,
    }),
  );

  @override
  Future<void> setBoarding(
    String routeId,
    String studentId,
    BoardingStatus status,
  ) => _act(
    () => _api.post('/transport/routes/$routeId/trip/boarding', {
      'studentId': studentId,
      'status': switch (status) {
        BoardingStatus.onBoard => 'onBoard',
        BoardingStatus.absent => 'absent',
        _ => 'waiting',
      },
    }),
  );

  @override
  Future<void> reportDelay(String routeId, int minutes, String reason) => _act(
    () => _api.post('/transport/routes/$routeId/trip/delay', {
      'minutes': minutes,
      'reason': reason,
    }),
  );

  @override
  Future<void> endTrip(String routeId, {String? earlyReason}) => _act(
    () => _api.post('/transport/routes/$routeId/trip/end', {
      'earlyReason': earlyReason,
    }),
  );

  // ---------- Administrator ----------

  @override
  Future<BusRouteModel> saveRoute(BusRouteModel route) => _act(() async {
    final json = route.id.isEmpty
        ? await _api.post('/transport/routes', route.toJson())
        : await _api.patch('/transport/routes/${route.id}', route.toJson());
    return BusRouteModel.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<void> deleteRoute(String routeId) =>
      _act(() => _api.delete('/transport/routes/$routeId'));

  @override
  Future<void> saveRouteStudent(String routeId, RouteStudentModel student) =>
      _act(
        () => _api.put('/transport/routes/$routeId/students/${student.id}', {
          'stopId': student.stopId,
        }),
      );

  @override
  Future<void> removeRouteStudent(String routeId, String studentId) =>
      _act(() => _api.delete('/transport/routes/$routeId/students/$studentId'));

  @override
  Future<void> saveSettings(TransportSettingsModel settings) =>
      _act(() => _api.put('/transport/settings', settings.toJson()));

  @override
  Future<List<PlaceModel>> searchPlaces(String text) => _act(() async {
    final list =
        await _api.get('/transport/places?q=${Uri.encodeQueryComponent(text)}')
            as List;
    return [
      for (final json in list)
        PlaceModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  @override
  Future<StudentHomeModel?> getStudentHome(String studentId) async {
    final json = await _api.get('/transport/students/$studentId/home');
    return json == null
        ? null
        : StudentHomeModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> saveStudentHome(String studentId, StudentHomeModel home) => _act(
    () => _api.put('/transport/students/$studentId/home', home.toJson()),
  );

  @override
  Future<LatLng> readLocation(String text) => _act(() async {
    final json =
        await _api.post('/transport/read-location', {'text': text})
            as Map<String, dynamic>;
    return LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    );
  });

  /// The screens show [TransportException] messages; the server's refusals
  /// ("Bus 12 is full", "too early for this trip") arrive as those.
  Future<T> _act<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw TransportException(e.message);
    }
  }
}
