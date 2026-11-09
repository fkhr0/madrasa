/// A place found by name on the map (OpenStreetMap), to put a stop there.
class PlaceModel {
  final String name;

  /// The full address, e.g. "Al-Yarmouk Hospital, Al-Yarmouk, Baghdad".
  final String address;
  final double latitude;
  final double longitude;

  const PlaceModel({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}
