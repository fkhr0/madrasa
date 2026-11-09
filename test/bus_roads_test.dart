import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:school/features/auth/data/mock_users.dart';
import 'package:school/features/auth/providers/auth_provider.dart';
import 'package:school/features/notifications/models/notification_model.dart';
import 'package:school/features/notifications/providers/notification_provider.dart';
import 'package:school/features/transport/data/mock_transport.dart';
import 'package:school/features/transport/logic/stop_planning.dart';
import 'package:school/features/transport/models/road_path_model.dart';
import 'package:school/features/transport/models/trip_model.dart';

void main() {
  // Two drives: an L-shaped street, then a straight one.
  final road = RoadPathModel.fromJson({
    'legs': [
      [
        [33.30, 44.30],
        [33.30, 44.31],
        [33.31, 44.31],
      ],
      [
        [33.31, 44.31],
        [33.32, 44.31],
      ],
    ],
    'metres': 3300,
    'seconds': 600,
    'legSeconds': [420, 180],
  })!;

  test('the bus follows the bends of the street', () {
    // Halfway along the L is near its corner, on the street, not the
    // straight-line midpoint (33.305, 44.305) across the buildings.
    final half = road.along(0, 0.5);
    expect(half.latitude, closeTo(33.30, 0.002));
    expect(half.longitude, closeTo(44.31, 0.0001));
    expect(road.along(1, 1), const LatLng(33.32, 44.31));
    expect(road.summary, '3.3 km · 10 min');
  });

  test('stop times from the real driving times', () {
    final line = MockTransport.karradaLine; // k1, k2, school
    final planned = timesFromRoads(line.stops, road, null);

    final school = line.stops.last;
    expect(planned.last.morningMinute, school.morningMinute);
    // 3 min drive + 1 min wait before the school; 7 + 1 before that.
    expect(planned[1].morningMinute, school.morningMinute - 4);
    expect(planned[0].morningMinute, school.morningMinute - 12);
    // Afternoon runs from the school outwards.
    expect(planned[1].afternoonMinute, school.afternoonMinute + 8);
  });

  test('a line only uses a road that matches its stops', () {
    final line = MockTransport.karradaLine;
    expect(line.copyWith().roadFor(TripDirection.toSchool), isNull);
  });

  test('drivers only hear about their bus', () async {
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(MockUsers.driver)],
    );
    addTearDown(container.dispose);

    final items = await container.read(notificationsProvider.future);
    expect(items.every((n) => n.type == NotificationType.transport), isTrue);
  });
}
