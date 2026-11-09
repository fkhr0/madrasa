import 'package:latlong2/latlong.dart';

import '../models/bus_route_model.dart';
import '../models/place_model.dart';
import '../models/route_student_model.dart';
import '../models/student_home_model.dart';
import '../models/student_transport_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';

/// School transport (doc §3.20).
abstract class TransportRepository {
  // ---------- Students and parents ----------
  /// The student's route and stop, or null if they don't use the bus.
  Future<StudentTransportModel?> getStudentTransport(String studentId);

  /// Parent: the child won't ride today (the driver is told).
  Future<void> setNotRidingToday(String studentId, bool notRiding);

  // ---------- Everyone ----------
  /// Live state of a route's current trip. Emits again on every update.
  Stream<TripModel> watchTrip(String routeId);

  Future<BusRouteModel?> getRoute(String routeId);

  /// Students registered on the route, sorted by stop.
  Future<List<RouteStudentModel>> getRouteStudents(String routeId);

  /// All routes of the school.
  Future<List<BusRouteModel>> getRoutes();

  /// The route a driver is assigned to, if any.
  Future<BusRouteModel?> getDriverRoute(String driverId);

  Future<TransportSettingsModel> getSettings();

  /// Trips of the route finished today, with the time they ended.
  Future<Map<TripDirection, DateTime>> getFinishedTrips(String routeId);

  // ---------- Driver ----------
  /// Throws [TransportException] when the trip rules don't allow it
  /// (see `logic/trip_rules.dart`).
  Future<void> startTrip(String routeId, TripDirection direction);

  /// Leave the current stop and drive to the next one.
  Future<void> leaveStop(String routeId);

  /// The driver says the bus reached the next stop (when GPS is off).
  Future<void> arriveAtStop(String routeId);

  /// The driver's phone, every few seconds during a trip. The server moves
  /// the bus on by itself when it leaves or reaches a stop. [accuracy] is
  /// in metres (rough readings don't decide arrivals).
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

  /// Ends the trip. [earlyReason] is set when it ends before the last
  /// stop (breakdown, road closed...); families and the office are told.
  Future<void> endTrip(String routeId, {String? earlyReason});

  // ---------- Administrator ----------
  /// Creates the route when its ID is empty, otherwise updates it.
  Future<BusRouteModel> saveRoute(BusRouteModel route);

  /// Throws [TransportException] while the bus is on a trip.
  Future<void> deleteRoute(String routeId);

  /// Adds the student to the route, or moves them to another stop.
  /// Throws [TransportException] when the bus is full.
  Future<void> saveRouteStudent(String routeId, RouteStudentModel student);

  Future<void> removeRouteStudent(String routeId, String studentId);

  Future<void> saveSettings(TransportSettingsModel settings);

  /// Places in Iraq matching [text] ("Yarmouk hospital"), to add stops.
  Future<List<PlaceModel>> searchPlaces(String text);

  // ---------- Door to door ----------
  /// Where the student lives, if the family or school set it.
  Future<StudentHomeModel?> getStudentHome(String studentId);

  /// The family shares it, or the school sets it.
  Future<void> saveStudentHome(String studentId, StudentHomeModel home);

  /// Reads a WhatsApp / Google Maps location link (or "33.3, 44.3").
  /// Throws [TransportException] when there's no place in Iraq in it.
  Future<LatLng> readLocation(String text);
}

class TransportException implements Exception {
  final String message;

  const TransportException(this.message);

  @override
  String toString() => message;
}
