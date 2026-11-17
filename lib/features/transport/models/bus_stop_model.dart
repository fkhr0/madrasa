class BusStopModel {
  final String id;
  final String name;

  final String landmark;

  final double latitude;
  final double longitude;

  final int morningMinute;
  final int afternoonMinute;

  const BusStopModel({
    required this.id,
    required this.name,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    required this.morningMinute,
    required this.afternoonMinute,
  });

  factory BusStopModel.fromJson(Map<String, dynamic> json) {
    return BusStopModel(
      id: json['id'] as String,
      name: json['name'] as String,
      landmark: json['landmark'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      morningMinute: (json['morningMinute'] as num).toInt(),
      afternoonMinute: (json['afternoonMinute'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.startsWith(newIdPrefix) ? '' : id,
    'name': name,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'morningMinute': morningMinute,
    'afternoonMinute': afternoonMinute,
  };

  static const newIdPrefix = 'new-';

  static const schoolId = 'school';

  bool get isSchool => id == schoolId;

  static const homeSuffix = "'s home";

  bool get isHome => name.endsWith(homeSuffix);

  BusStopModel copyWith({
    String? name,
    String? landmark,
    double? latitude,
    double? longitude,
    int? morningMinute,
    int? afternoonMinute,
  }) {
    return BusStopModel(
      id: id,
      name: name ?? this.name,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      morningMinute: morningMinute ?? this.morningMinute,
      afternoonMinute: afternoonMinute ?? this.afternoonMinute,
    );
  }
}
