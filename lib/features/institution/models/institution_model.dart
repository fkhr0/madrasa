/// The school: its name, contact details and its place on the map.
/// Every bus line ends at [latitude], [longitude].
class InstitutionModel {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;

  /// The school gate, or null until the administrator sets it.
  final double? latitude;
  final double? longitude;

  const InstitutionModel({
    required this.id,
    required this.name,
    required this.city,
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'city': city,
    'address': address,
    'phone': phone,
    'latitude': latitude,
    'longitude': longitude,
  };

  InstitutionModel copyWith({
    String? name,
    String? city,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
  }) {
    return InstitutionModel(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
