import 'bus_stop_model.dart';
import 'road_path_model.dart';
import 'trip_model.dart';

class BusRouteModel {
  final String id;
  final String name;
  final String busNumber;
  final String plateNumber;

  final String driverId;
  final String driverName;
  final String driverPhone;

  final String supervisorName;
  final String supervisorPhone;

  final List<BusStopModel> stops;

  final int studentCount;
  final int capacity;

  final RoadPathModel? roadToSchool;
  final RoadPathModel? roadToHome;

  const BusRouteModel({
    required this.id,
    required this.name,
    required this.busNumber,
    required this.plateNumber,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.supervisorName,
    required this.supervisorPhone,
    required this.stops,
    required this.capacity,
    this.studentCount = 0,
    this.roadToSchool,
    this.roadToHome,
  });

  RoadPathModel? roadFor(TripDirection direction) {
    final road = direction == TripDirection.toSchool
        ? roadToSchool
        : roadToHome;
    return road != null && road.legs.length == stops.length - 1 ? road : null;
  }

  factory BusRouteModel.fromJson(Map<String, dynamic> json) {
    return BusRouteModel(
      id: json['id'] as String,
      name: json['name'] as String,
      busNumber: json['busNumber'] as String,
      plateNumber: json['plateNumber'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      driverPhone: json['driverPhone'] as String? ?? '',
      supervisorName: json['supervisorName'] as String? ?? '',
      supervisorPhone: json['supervisorPhone'] as String? ?? '',
      capacity: (json['capacity'] as num).toInt(),
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      roadToSchool: RoadPathModel.fromJson(json['roadToSchool']),
      roadToHome: RoadPathModel.fromJson(json['roadToHome']),
      stops: [
        for (final s in json['stops'] as List)
          BusStopModel.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'busNumber': busNumber,
    'plateNumber': plateNumber,
    'driverId': driverId,
    'supervisorName': supervisorName,
    'supervisorPhone': supervisorPhone,
    'capacity': capacity,
    'stops': [for (final s in stops) s.toJson()],
  };

  bool get hasDriver => driverId.isNotEmpty;

  bool get isFull => studentCount >= capacity;

  int get freeSeats => (capacity - studentCount).clamp(0, capacity);

  List<BusStopModel> get pickUpStops =>
      stops.where((s) => !s.isSchool).toList();

  BusRouteModel copyWith({
    String? name,
    String? busNumber,
    String? plateNumber,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? supervisorName,
    String? supervisorPhone,
    List<BusStopModel>? stops,
    int? studentCount,
    int? capacity,
  }) {
    return BusRouteModel(
      id: id,
      name: name ?? this.name,
      busNumber: busNumber ?? this.busNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorPhone: supervisorPhone ?? this.supervisorPhone,
      stops: stops ?? this.stops,
      studentCount: studentCount ?? this.studentCount,
      capacity: capacity ?? this.capacity,
      roadToSchool: stops == null ? roadToSchool : null,
      roadToHome: stops == null ? roadToHome : null,
    );
  }
}
