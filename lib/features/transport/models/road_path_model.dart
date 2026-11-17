import 'package:latlong2/latlong.dart';
import '../../../core/l10n/language.dart';

class RoadPathModel {
  final List<List<LatLng>> legs;
  final int metres;
  final int seconds;

  final List<int> legSeconds;

  const RoadPathModel({
    required this.legs,
    required this.metres,
    required this.seconds,
    required this.legSeconds,
  });

  List<LatLng> get points => [for (final leg in legs) ...leg];

  int get minutes => (seconds / 60).round();

  String get summary =>
      tr('{0} km · {1} min', [(metres / 1000).toStringAsFixed(1), minutes]);

  static RoadPathModel? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return RoadPathModel(
      legs: [
        for (final leg in json['legs'] as List)
          [
            for (final p in leg as List)
              LatLng(
                ((p as List)[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ),
          ],
      ],
      metres: (json['metres'] as num).toInt(),
      seconds: (json['seconds'] as num).toInt(),
      legSeconds: [
        for (final s in json['legSeconds'] as List) (s as num).toInt(),
      ],
    );
  }

  LatLng along(int index, double fraction) {
    final leg = legs[index];
    if (leg.length == 1 || fraction <= 0) return leg.first;
    if (fraction >= 1) return leg.last;

    const distance = Distance();
    final lengths = [
      for (var i = 1; i < leg.length; i++) distance(leg[i - 1], leg[i]),
    ];
    var remaining = lengths.fold<double>(0, (a, b) => a + b) * fraction;
    for (var i = 0; i < lengths.length; i++) {
      if (remaining <= lengths[i] && lengths[i] > 0) {
        final t = remaining / lengths[i];
        final a = leg[i];
        final b = leg[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      remaining -= lengths[i];
    }
    return leg.last;
  }
}
