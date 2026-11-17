import 'package:latlong2/latlong.dart';

import '../models/bus_route_model.dart';
import '../models/place_model.dart';
import '../models/route_student_model.dart';
import '../models/student_home_model.dart';
import '../models/student_transport_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';

abstract class TransportRepository {
  Future<StudentTransportModel?> getStudentTransport(String studentId);

  Future<void> setNotRidingToday(String studentId, bool notRiding);

  Stream<TripModel> watchTrip(String routeId);

  Future<BusRouteModel?> getRoute(String routeId);

  Future<List<RouteStudentModel>> getRouteStudents(String routeId);

  Future<List<BusRouteModel>> getRoutes();

  Future<BusRouteModel?> getDriverRoute(String driverId);

  Future<TransportSettingsModel> getSettings();

  Future<Map<TripDirection, DateTime>> getFinishedTrips(String routeId);

  Future<void> startTrip(String routeId, TripDirection direction);

  Future<void> leaveStop(String routeId);

  Future<void> arriveAtStop(String routeId);

  Future<void> sendLocation(
    String routeId,
    double latitude,
    double longitude, {
    double? accuracy,
  });

  Future<void> setBoarding(
    String routeId,
    String studentId,
    BoardingStatus status,
  );

  Future<void> reportDelay(String routeId, int minutes, String reason);

  Future<void> endTrip(String routeId, {String? earlyReason});

  Future<BusRouteModel> saveRoute(BusRouteModel route);

  Future<void> deleteRoute(String routeId);

  Future<void> saveRouteStudent(String routeId, RouteStudentModel student);

  Future<void> removeRouteStudent(String routeId, String studentId);

  Future<void> saveSettings(TransportSettingsModel settings);

  Future<List<PlaceModel>> searchPlaces(String text);

  Future<StudentHomeModel?> getStudentHome(String studentId);

  Future<void> saveStudentHome(String studentId, StudentHomeModel home);

  Future<LatLng> readLocation(String text);
}

class TransportException implements Exception {
  final String message;

  const TransportException(this.message);

  @override
  String toString() => message;
}
