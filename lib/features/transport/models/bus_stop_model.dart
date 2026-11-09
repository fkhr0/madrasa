/// One stop on a bus route.
class BusStopModel {
  final String id;
  final String name;

  /// Something easy to recognise, e.g. "Al-Yarmouk hospital".
  final String landmark;

  /// Position for the live map (GPS stage).
  final double latitude;
  final double longitude;

  /// Planned times, in minutes after midnight (07:22 → 442).
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

  /// A stop made in the app has no server ID yet: it is sent empty.
  Map<String, dynamic> toJson() => {
    'id': id.startsWith(newIdPrefix) ? '' : id,
    'name': name,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'morningMinute': morningMinute,
    'afternoonMinute': afternoonMinute,
  };

  /// IDs of stops added in the app and not saved yet start with this.
  static const newIdPrefix = 'new-';

  /// The school is always the last stop of the morning order.
  static const schoolId = 'school';

  bool get isSchool => id == schoolId;

  /// A door-to-door stop made from one family's home ("Zainab's home").
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
