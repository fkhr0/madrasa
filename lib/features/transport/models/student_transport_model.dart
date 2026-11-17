import 'bus_route_model.dart';
import 'bus_stop_model.dart';

class StudentTransportModel {
  final BusRouteModel route;
  final String stopId;

  final bool notRidingToday;

  const StudentTransportModel({
    required this.route,
    required this.stopId,
    this.notRidingToday = false,
  });

  BusStopModel get myStop => route.stops.firstWhere((s) => s.id == stopId);
}
