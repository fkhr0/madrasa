import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/auth/data/mock_users.dart';
import 'package:school/features/notifications/data/demo_notifier.dart';
import 'package:school/features/transport/data/mock_transport.dart';
import 'package:school/features/transport/models/route_student_model.dart';
import 'package:school/features/transport/models/trip_model.dart';
import 'package:school/features/transport/repo/live_trip.dart';
import 'package:school/features/transport/repo/mock_transport_repository.dart';

void main() {
  group('LiveTrip (driver test mode)', () {
    final t0 = DateTime(2026, 11, 4, 6, 50);

    test('starts at the first stop and drives to the next', () {
      final trip = LiveTrip.start(
        MockTransport.mansourLine,
        TripDirection.toSchool,
        t0,
      );
      expect(trip.toModel(t0).isAtStop, isTrue);
      expect(trip.toModel(t0).lastReachedIndex, 0);

      trip.leave(t0);
      final halfway = t0.add(LiveTrip.demoDriveTime ~/ 2);
      final moving = trip.toModel(halfway);
      expect(moving.isAtStop, isFalse);
      // The bus is between stop 1 and stop 2 on the map.
      final a = MockTransport.mansourLine.stops[0];
      final b = MockTransport.mansourLine.stops[1];
      expect(moving.longitude, closeTo((a.longitude + b.longitude) / 2, 1e-6));

      expect(trip.advance(halfway), isNull);
      expect(trip.advance(t0.add(LiveTrip.demoDriveTime)), 1);
      expect(trip.toModel(t0).isAtStop, isTrue);
    });

    test('afternoon trip starts at school', () {
      final trip = LiveTrip.start(
        MockTransport.mansourLine,
        TripDirection.toHome,
        t0,
      );
      expect(trip.stops.first.id, 'school');
    });
  });

  group('Boarding status', () {
    const zainab = RouteStudentModel(
      id: 'z',
      name: 'Zainab',
      stopId: 's4',
      className: '',
      parentId: 'p',
      parentName: '',
      parentPhone: '',
    );

    test('waiting, on board, not riding', () {
      final trip = LiveTrip.start(
        MockTransport.mansourLine,
        TripDirection.toSchool,
        DateTime(2026, 11, 4, 7),
      );
      expect(
        trip.toModel(DateTime.now()).statusOf(zainab),
        BoardingStatus.waiting,
      );

      trip.boarded.add('z');
      expect(
        trip.toModel(DateTime.now()).statusOf(zainab),
        BoardingStatus.onBoard,
      );

      expect(
        trip
            .toModel(DateTime.now())
            .statusOf(zainab.copyWith(notRidingToday: true)),
        BoardingStatus.notRiding,
      );
    });
  });

  group('Driver actions notify the right people', () {
    test('start, boarding and "not riding today"', () async {
      final notifier = DemoNotifier();
      final repo = MockTransportRepository(
        dayOffReason: (_) => null,
        notifier: notifier,
      );
      final zainab = MockUsers.student.id;
      final parent = MockUsers.parent.id;

      await repo.startTrip('route-1', TripDirection.toSchool);
      expect(notifier.itemsFor(parent).single.title, contains('started'));

      await repo.setBoarding('route-1', zainab, BoardingStatus.onBoard);
      expect(
        notifier.itemsFor(parent).last.title,
        'Zainab Haider is on bus 12',
      );

      await repo.setNotRidingToday(zainab, true);
      expect(
        notifier.itemsFor(MockUsers.driver.id).last.title,
        'Zainab Haider won\'t ride today',
      );

      await repo.endTrip('route-1');
    });
  });
}
