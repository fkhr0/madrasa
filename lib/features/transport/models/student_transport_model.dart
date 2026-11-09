import 'bus_route_model.dart';
import 'bus_stop_model.dart';

/// A student's place on a bus route.
class StudentTransportModel {
  final BusRouteModel route;
  final String stopId;

  /// The parent told the school the student won't ride today.
  final bool notRidingToday;

  const StudentTransportModel({
    required this.route,
    required this.stopId,
    this.notRidingToday = false,
  });

  BusStopModel get myStop => route.stops.firstWhere((s) => s.id == stopId);
}
