import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:school/core/utils/location_link.dart';
import 'package:school/features/notifications/data/demo_notifier.dart';
import 'package:school/features/transport/models/bus_stop_model.dart';
import 'package:school/features/transport/models/student_home_model.dart';
import 'package:school/features/transport/repo/mock_transport_repository.dart';
import 'package:school/features/transport/repo/transport_repository.dart';

void main() {
  group('reading what families send on WhatsApp', () {
    test('Google Maps links, geo: and plain numbers', () {
      expect(
        coordinatesIn(
          'https://maps.google.com/maps?q=33.3121%2C44.3612&z=17&hl=en',
        ),
        const LatLng(33.3121, 44.3612),
      );
      // The pin (!3d!4d) wins over the map's centre (@).
      expect(
        coordinatesIn(
          'https://www.google.com/maps/place/X/@33.2981,44.3323,17z/'
          'data=!3m1!4m6!3d33.2990!4d44.3330',
        ),
        const LatLng(33.2990, 44.3330),
      );
      expect(coordinatesIn('geo:33.31,44.36'), const LatLng(33.31, 44.36));
      expect(
        coordinatesIn(' 33.3121, 44.3612 '),
        const LatLng(33.3121, 44.3612),
      );
      expect(coordinatesIn('near the big mosque'), isNull);
    });

    test('only places in Iraq', () {
      expect(IraqMap.contains(const LatLng(33.31, 44.36)), isTrue); // Baghdad
      expect(IraqMap.contains(const LatLng(36.19, 44.01)), isTrue); // Erbil
      expect(IraqMap.contains(const LatLng(48.85, 2.35)), isFalse); // Paris
    });
  });

  test('a family shares its home; outside Iraq is refused', () async {
    final repo = MockTransportRepository(
      dayOffReason: (_) => null,
      notifier: DemoNotifier(),
    );
    const home = StudentHomeModel(
      point: LatLng(33.301, 44.336),
      note: 'Green gate',
      sharedByFamily: true,
    );

    await repo.saveStudentHome('STU-2026-0142', home);
    expect((await repo.getStudentHome('STU-2026-0142'))?.note, 'Green gate');

    expect(
      () => repo.saveStudentHome(
        'STU-2026-0142',
        const StudentHomeModel(point: LatLng(48.85, 2.35)),
      ),
      throwsA(isA<TransportException>()),
    );
    expect(
      () => repo.readLocation('near the big mosque'),
      throwsA(isA<TransportException>()),
    );
  });

  test('home stops are recognised by their name', () {
    const stop = BusStopModel(
      id: 's9',
      name: "Zainab's home",
      landmark: 'Green gate',
      latitude: 33.301,
      longitude: 44.336,
      morningMinute: 420,
      afternoonMinute: 840,
    );
    expect(stop.isHome, isTrue);
    expect(stop.copyWith(name: 'Al-Adel').isHome, isFalse);
  });
}
