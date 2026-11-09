import 'package:latlong2/latlong.dart';

/// Iraq's borders, roughly. Maps stay inside; places outside are refused.
class IraqMap {
  IraqMap._();

  static const south = 29.0;
  static const north = 37.5;
  static const west = 38.7;
  static const east = 48.9;

  static bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;
}

/// Finds a place in what a family sent: a WhatsApp / Google Maps link with
/// the coordinates inside, "geo:33.3,44.3", or "33.3121, 44.3612".
/// Short links (maps.app.goo.gl) need the server to follow them.
LatLng? coordinatesIn(String text) {
  final decoded = Uri.decodeFull(text).replaceAll('+', ' ');
  const number = r'(-?\d+\.\d+)';
  final patterns = [
    RegExp('!3d$number!4d$number'), // the pin itself
    RegExp('@$number,\\s*$number'), // the map's centre
    RegExp(
      '[?&](?:q|ll|query|destination|center)=(?:loc:)?$number,\\s*$number',
    ),
    RegExp('geo:$number,$number'),
    RegExp(r'^\s*(-?\d{1,2}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)\s*$'),
  ];

  for (final pattern in patterns) {
    final m = pattern.firstMatch(decoded);
    if (m != null) {
      return LatLng(double.parse(m.group(1)!), double.parse(m.group(2)!));
    }
  }
  return null;
}
