import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/network/api_exception.dart';
import 'package:school/features/institution/data/mock_institution.dart';
import 'package:school/features/institution/models/holiday_model.dart';
import 'package:school/features/institution/repo/mock_institution_repository.dart';
import 'package:school/features/transport/data/mock_transport.dart';
import 'package:school/features/transport/logic/server_trip.dart';
import 'package:school/features/transport/models/bus_route_model.dart';
import 'package:school/features/transport/models/bus_stop_model.dart';
import 'package:school/features/transport/models/trip_model.dart';

void main() {
  final route = MockTransport.mansourLine;

  test('a bus line goes to the server and back unchanged', () {
    final json = route.toJson()
      ..['id'] = route.id
      ..['driverName'] = route.driverName;
    final back = BusRouteModel.fromJson(json);

    expect(back.stops.length, route.stops.length);
    expect(back.stops.last.isSchool, isTrue);
    expect(back.driverName, route.driverName);

    // A stop added in the app is sent without an ID.
    final added = route.stops.first.copyWith();
    expect(
      BusStopModel(
        id: '${BusStopModel.newIdPrefix}1',
        name: added.name,
        landmark: '',
        latitude: 0,
        longitude: 0,
        morningMinute: 0,
        afternoonMinute: 0,
      ).toJson()['id'],
      '',
    );
  });

  group('trip from the server', () {
    final now = DateTime(2026, 11, 5, 13, 30);
    Map<String, dynamic> trip({
      String? leftStopAt,
      String? positionAt,
      double? lat,
      double? lng,
    }) => {
      'direction': 'toHome',
      'stopIds': ['school', 's5', 's4', 's3', 's2', 's1'],
      'reachedAt': [
        now.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
        now.subtract(const Duration(minutes: 2)).toUtc().toIso8601String(),
        null,
        null,
        null,
        null,
      ],
      'reachedIndex': 1,
      'leftStopAt': leftStopAt,
      'delayMinutes': 5,
      'delayReason': 'Traffic',
      'latitude': lat,
      'longitude': lng,
      'positionAt': positionAt,
      'boardedIds': ['STU-2026-0142'],
      'absentIds': <String>[],
    };

    test('standing at a stop', () {
      final t = tripFromServer(
        route: route,
        json: trip(),
        now: now,
        testMode: false,
      );

      expect(t.direction, TripDirection.toHome);
      expect(t.stops.first.isSchool, isTrue);
      expect(t.isAtStop, isTrue);
      expect(t.lastReachedIndex, 1);
      expect(t.latitude, t.stops[1].latitude);
      expect(t.boardedIds, contains('STU-2026-0142'));
      // Next stop: the timetable's 10 minutes from Al-Mansour to Al-Yarmouk.
      expect(t.expectedAt(2), now.add(const Duration(minutes: 10)));
    });

    test('a new trip starts where the driver is, not at the first stop', () {
      final first = route.stops.last; // the afternoon trip starts at school
      final t = tripFromServer(
        route: route,
        json: {
          ...trip(
            leftStopAt: now.toUtc().toIso8601String(),
            positionAt: now.toUtc().toIso8601String(),
            // About 1 km north of the school.
            lat: first.latitude + 0.009,
            lng: first.longitude,
          ),
          'reachedIndex': -1,
          'reachedAt': List.filled(6, null),
        },
        now: now,
        testMode: false,
      );

      expect(t.lastReachedIndex, -1);
      expect(t.isAtStop, isFalse);
      expect(t.nextStopIndex, 0);
      expect(t.latitude, first.latitude + 0.009);
      // 1 km × 1.3 for the streets at ~25 km/h: about 3 minutes away.
      expect(t.minutesUntil(0, now), inInclusiveRange(2, 4));
    });

    test('fresh GPS places the bus where the phone is', () {
      final t = tripFromServer(
        route: route,
        json: trip(
          leftStopAt: now
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String(),
          positionAt: now
              .subtract(const Duration(seconds: 4))
              .toUtc()
              .toIso8601String(),
          lat: 33.305,
          lng: 44.342,
        ),
        now: now,
        testMode: true,
      );

      expect(t.isAtStop, isFalse);
      expect(t.latitude, 33.305);
      expect(t.nextStopIndex, 2);
    });
  });

  test('official holidays can be moved but not deleted', () async {
    final repo = MockInstitutionRepository();
    final eid = MockInstitution.academicYear.holidays.firstWhere(
      (h) => h.name == 'Eid al-Fitr',
    );

    expect(() => repo.removeHoliday(eid), throwsA(isA<ApiException>()));

    await repo.updateHoliday(
      eid,
      HolidayModel(
        name: 'Renamed',
        type: HolidayType.schoolBreak,
        start: DateTime(2027, 3, 10),
        end: DateTime(2027, 3, 13),
      ),
    );
    final moved = (await repo.getCurrentAcademicYear()).holidays.firstWhere(
      (h) => h.name == 'Eid al-Fitr',
    );
    expect(moved.start, DateTime(2027, 3, 10));
    expect(moved.type, HolidayType.religious);
    expect(moved.isOfficial, isTrue);
  });
}
