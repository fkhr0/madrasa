import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/utils/money_formatter.dart';
import 'package:school/features/auth/data/mock_users.dart';
import 'package:school/features/finance/data/mock_finance.dart';
import 'package:school/features/finance/models/payment_model.dart';
import 'package:school/features/finance/models/student_account_model.dart';
import 'package:school/features/finance/repo/finance_repository.dart';
import 'package:school/features/finance/repo/mock_finance_repository.dart';
import 'package:school/features/insights/data/mock_insights.dart';
import 'package:school/features/insights/logic/highlights.dart';
import 'package:school/features/insights/models/insights_model.dart';
import 'package:school/features/notifications/data/demo_notifier.dart';
import 'package:school/features/transport/data/mock_transport.dart';
import 'package:school/features/transport/logic/stop_planning.dart';
import 'package:school/features/transport/logic/trip_rules.dart';
import 'package:school/features/transport/models/bus_route_model.dart';
import 'package:school/features/transport/models/bus_stop_model.dart';
import 'package:school/features/transport/models/route_student_model.dart';
import 'package:school/features/transport/models/transport_settings_model.dart';
import 'package:school/features/transport/models/trip_model.dart';
import 'package:school/features/transport/repo/mock_transport_repository.dart';
import 'package:school/features/transport/repo/transport_repository.dart';

void main() {
  final route = MockTransport.mansourLine;
  const strict = TransportSettingsModel(testMode: false);
  DateTime at(int hour, int minute) => DateTime(2026, 11, 4, hour, minute);

  group('Trip rules', () {
    // Morning: first stop 06:50, school 07:45 → window 06:05–08:45.
    TripAvailability morning(DateTime now, {DateTime? doneAt}) => checkTrip(
      route: route,
      direction: TripDirection.toSchool,
      now: now,
      settings: strict,
      doneAt: doneAt,
    );

    test('a trip opens and closes around its timetable', () {
      expect(morning(at(5, 30)).block, TripBlock.tooEarly);
      expect(morning(at(6, 30)).block, TripBlock.none);
      expect(morning(at(9, 0)).block, TripBlock.tooLate);
    });

    test('no morning trip in the afternoon', () {
      final afternoon = morning(at(14, 0));
      expect(afternoon.canStart, isFalse);

      final homeTrip = checkTrip(
        route: route,
        direction: TripDirection.toHome,
        now: at(13, 10),
        settings: strict,
      );
      expect(homeTrip.isOpen, isTrue);
    });

    test('once a day, never on holidays, one trip at a time', () {
      expect(
        morning(at(6, 30), doneAt: at(7, 46)).block,
        TripBlock.alreadyDone,
      );
      expect(
        checkTrip(
          route: route,
          direction: TripDirection.toSchool,
          now: at(6, 30),
          settings: strict,
          dayOffReason: 'Eid al-Fitr',
        ).block,
        TripBlock.noSchool,
      );
      expect(
        checkTrip(
          route: route,
          direction: TripDirection.toHome,
          now: at(13, 10),
          settings: strict,
          runningTrip: TripDirection.toSchool,
        ).block,
        TripBlock.otherTripRunning,
      );
    });

    test('test mode skips the clock but not the safety rules', () {
      const relaxed = TransportSettingsModel(testMode: true);
      final late = checkTrip(
        route: route,
        direction: TripDirection.toSchool,
        now: at(20, 0),
        settings: relaxed,
      );
      expect(late.canStart, isTrue);
      expect(late.startsByTestMode, isTrue);

      final busy = checkTrip(
        route: route,
        direction: TripDirection.toHome,
        now: at(20, 0),
        settings: relaxed,
        runningTrip: TripDirection.toSchool,
      );
      expect(busy.canStart, isFalse);
    });

    test('the open trip is suggested first', () {
      final trips = [
        for (final d in TripDirection.values)
          checkTrip(
            route: route,
            direction: d,
            now: at(13, 0),
            settings: strict,
          ),
      ];
      expect(suggestedTrip(trips).direction, TripDirection.toHome);
    });
  });

  group('Administrator transport changes', () {
    MockTransportRepository repo() => MockTransportRepository(
      dayOffReason: (_) => null,
      notifier: DemoNotifier(),
    );

    test('the repository refuses a trip the rules forbid', () async {
      final r = MockTransportRepository(
        dayOffReason: (_) => 'Weekend',
        notifier: DemoNotifier(),
      );
      await r.saveSettings(strict);

      expect(
        () => r.startTrip('route-1', TripDirection.toSchool),
        throwsA(isA<TransportException>()),
      );
    });

    test('a driver drives one bus', () async {
      final r = repo();
      final karrada = (await r.getRoute('route-2'))!;
      await r.saveRoute(
        karrada.copyWith(
          driverId: MockUsers.driver.id,
          driverName: MockUsers.driver.name,
        ),
      );

      expect((await r.getDriverRoute(MockUsers.driver.id))!.id, 'route-2');
      expect((await r.getRoute('route-1'))!.hasDriver, isFalse);
    });

    test('a student rides one bus, and a full bus says no', () async {
      final r = repo();
      final zainab = (await r.getRouteStudents(
        'route-1',
      )).firstWhere((s) => s.id == MockUsers.student.id);

      await r.saveRouteStudent('route-2', zainab.copyWith(stopId: 'k1'));
      expect(
        (await r.getStudentTransport(MockUsers.student.id))!.route.id,
        'route-2',
      );

      final karrada = (await r.getRoute('route-2'))!;
      await r.saveRoute(karrada.copyWith(capacity: karrada.studentCount));
      expect(
        () => r.saveRouteStudent(
          'route-2',
          const RouteStudentModel(
            id: 'STU-NEW',
            name: 'New Student',
            stopId: 'k1',
            className: '',
            parentId: '',
            parentName: '',
            parentPhone: '',
          ),
        ),
        throwsA(isA<TransportException>()),
      );
    });

    test('a line on a trip cannot be deleted', () async {
      final r = repo();
      await r.startTrip('route-1', TripDirection.toSchool);
      expect(
        () => r.deleteRoute('route-1'),
        throwsA(isA<TransportException>()),
      );
      await r.endTrip('route-1');
      await r.deleteRoute('route-1');
      expect(await r.getRoute('route-1'), isNull);
    });

    test('a new line starts at the school', () async {
      final r = repo();
      final saved = await r.saveRoute(
        const BusRouteModel(
          id: '',
          name: 'Al-Adhamiya line',
          busNumber: '15',
          plateNumber: '',
          driverId: '',
          driverName: '',
          driverPhone: '',
          supervisorName: '',
          supervisorPhone: '',
          stops: [],
          capacity: 20,
        ),
      );
      expect(saved.stops.single.isSchool, isTrue);
    });
  });

  group('Stop planning', () {
    test('a new stop goes where it adds the least driving', () {
      // Between Al-Ghazaliya (s1) and Al-Adel (s2).
      final index = bestInsertIndex(route.stops, 33.334, 44.285);
      expect(index, 1);
    });

    test('wrong times are found and fixed', () {
      final stops = [...route.stops];
      stops[2] = stops[2].copyWith(morningMinute: 400); // before stop 1
      expect(timetableProblem(stops), isNotNull);
      expect(timetableProblem(evenTimes(stops)), isNull);
    });

    test('afternoon mirrors the morning', () {
      const school = MockTransport.school; // 07:45 / 13:20
      expect(afternoonFor(school, 7 * 60 + 25), 13 * 60 + 40);
      expect(school.id, BusStopModel.schoolId);
    });
  });

  group('Fees', () {
    final now = DateTime(2026, 11, 4);

    test('installments add up to the total', () {
      for (final a in MockFinance.accounts()) {
        final sum = a.installments.fold(0, (s, i) => s + i.amount);
        expect(sum, a.total);
      }
    });

    test('Zainab is on track, her brother is overdue', () {
      final accounts = MockFinance.accounts();
      final zainab = accounts.firstWhere(
        (a) => a.studentId == MockUsers.student.id,
      );
      final ali = accounts.firstWhere(
        (a) => a.studentId == MockUsers.secondStudent.id,
      );

      expect(zainab.status(now), AccountStatus.onTrack);
      expect(zainab.busFee, MockFinance.busFee);
      expect(ali.status(now), AccountStatus.overdue);
      expect(ali.overdueAmount(now), greaterThan(0));
    });

    test('a payment is checked, saved and the parent is told', () async {
      final notifier = DemoNotifier();
      final repo = MockFinanceRepository(notifier: notifier);
      final id = MockUsers.secondStudent.id;
      final before = (await repo.getAccount(id))!;

      expect(
        () => repo.recordPayment(
          studentId: id,
          amount: before.balance + 1,
          method: PaymentMethod.cash,
        ),
        throwsA(isA<FinanceException>()),
      );

      await repo.recordPayment(
        studentId: id,
        amount: before.overdueAmount(now),
        method: PaymentMethod.cash,
      );
      final after = (await repo.getAccount(id))!;
      expect(after.overdueAmount(now), 0);
      expect(
        notifier.itemsFor(MockUsers.parent.id).last.title,
        contains('Payment received'),
      );
    });

    test('money reads the Iraqi way', () {
      expect(MoneyFormatter.iqd(1250000), '1,250,000 IQD');
      expect(MoneyFormatter.compact(1250000), '1.25M');
      expect(MoneyFormatter.compact(750000), '750K');
    });
  });

  test('statistics point out problems first', () {
    final highlights = highlightsFor(
      MockInsights.forPeriod(InsightsPeriod.month),
    );
    expect(highlights, isNotEmpty);
    expect(highlights.first.isGood, isFalse);
    expect(highlights.any((h) => h.text.contains('Physics')), isTrue);
  });
}
