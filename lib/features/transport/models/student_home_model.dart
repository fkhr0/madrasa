import 'package:latlong2/latlong.dart';

/// Where a student lives, for door-to-door pick-up.
class StudentHomeModel {
  final LatLng point;

  /// A few words to find the door, e.g. "green gate next to the bakery".
  final String note;

  /// True when the family shared it (false: the school set it).
  final bool sharedByFamily;
  final DateTime? updatedAt;

  const StudentHomeModel({
    required this.point,
    this.note = '',
    this.sharedByFamily = false,
    this.updatedAt,
  });

  factory StudentHomeModel.fromJson(Map<String, dynamic> json) {
    final updated = json['updatedAt'] as String?;
    return StudentHomeModel(
      point: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      note: json['note'] as String? ?? '',
      sharedByFamily: json['setBy'] == 'family',
      updatedAt: updated == null ? null : DateTime.parse(updated).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': point.latitude,
    'longitude': point.longitude,
    'note': note,
  };
}
