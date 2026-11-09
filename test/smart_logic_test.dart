import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/assignments/models/assignment_model.dart';
import 'package:school/features/exams/models/exam_model.dart';
import 'package:school/features/institution/data/mock_institution.dart';
import 'package:school/features/planner/logic/student_rules.dart';
import 'package:school/features/planner/models/plan_tip_model.dart';
import 'package:school/features/schedule/data/mock_schedule.dart';
import 'package:school/features/subjects/data/mock_subjects.dart';
import 'package:school/features/today/logic/day_status_resolver.dart';
import 'package:school/features/today/models/day_status.dart';
import 'package:school/features/transport/data/mock_transport.dart';
import 'package:school/features/transport/data/trip_simulator.dart';
import 'package:school/features/transport/logic/trip_text.dart';
import 'package:school/features/transport/models/trip_model.dart';

void main() {
  final year = MockInstitution.academicYear;

  // Wednesday 4 Nov 2026: a normal school day with 6 lessons.
  final wednesday = DateTime(2026, 11, 4);
  final lessons = MockSchedule.lessonsFor(wednesday);
  final thursday = DateTime(2026, 11, 5);
  final next = UpcomingDay(
    date: thursday,
    lessons: MockSchedule.lessonsFor(thursday),
  );

  DayStatus statusAt(DateTime now) => resolveDayStatus(
    now: now,
    year: year,
    todayLessons: MockSchedule.lessonsFor(now),
    next: next,
  );

  group('Day status', () {
    test('before the first class', () {
      final s = statusAt(wednesday.add(const Duration(hours: 7)));
      expect(s, isA<BeforeSchool>());
      expect((s as BeforeSchool).lessonCount, lessons.length);
    });

    test('during a class knows the period and the next class', () {
      final s = statusAt(wednesday.copyWith(hour: 8, minute: 10));
      expect(s, isA<InClass>());
      s as InClass;
      expect(s.period, 1);
      expect(s.nextLesson?.id, lessons[1].id);
    });

    test('in the break shows the next class', () {
      final s = statusAt(wednesday.copyWith(hour: 10, minute: 30));
      expect(s, isA<BetweenClasses>());
      expect((s as BetweenClasses).nextLesson.id, lessons[3].id);
    });

    test('after the last class looks at the next school day', () {
      final s = statusAt(wednesday.copyWith(hour: 15));
      expect(s, isA<SchoolOver>());
      s as SchoolOver;
      expect(s.hadClassesToday, isTrue);
      expect(s.next?.date, thursday);
    });

    test('weekend and holidays are days off', () {
      final friday = statusAt(DateTime(2026, 11, 6, 9));
      expect(friday, isA<DayOff>());
      expect((friday as DayOff).holiday, isNull);

      final armyDay = statusAt(DateTime(2027, 1, 6, 9));
      expect((armyDay as DayOff).holiday?.name, 'Army Day');
    });

    test('outside the study year', () {
      final summer = statusAt(DateTime(2027, 7, 1, 9));
      expect(summer, isA<OutsideYear>());
      expect((summer as OutsideYear).notStartedYet, isFalse);
    });
  });

  group('Student planner rules', () {
    final now = DateTime(2026, 11, 4, 16);

    AssignmentModel assignment(String id, DateTime due) => AssignmentModel(
      id: id,
      title: 'Work $id',
      subject: MockSubjects.math,
      type: AssignmentType.homework,
      description: '',
      assignedAt: now.subtract(const Duration(days: 3)),
      dueDate: due,
      status: AssignmentStatus.pending,
      allowsLateSubmission: true,
    );

    ExamModel exam(String id, DateTime start) => ExamModel(
      id: id,
      subject: MockSubjects.physics,
      type: ExamType.monthly,
      start: start,
      durationMinutes: 90,
      room: 'Hall A',
    );

    test('overdue work comes first and says late work is accepted', () {
      final tips = sortTips(
        studentTips(
          now: now,
          assignments: [
            assignment('late', now.subtract(const Duration(days: 2))),
            assignment('week', now.add(const Duration(days: 4))),
          ],
          exams: const [],
          tasks: const [],
        ),
      );

      expect(tips.first.id, 'overdue-late');
      expect(tips.first.detail, contains('late work is still accepted'));
      expect(tips.last.when, PlanWhen.thisWeek);
    });

    test('an exam plus a deadline tomorrow flags a busy day', () {
      final tomorrow = DateTime(2026, 11, 5, 8);
      final tips = studentTips(
        now: now,
        assignments: [assignment('a', tomorrow.copyWith(hour: 23))],
        exams: [exam('e', tomorrow)],
        tasks: const [],
      );

      expect(tips.map((t) => t.id), contains('busy-tomorrow'));
      expect(tips.map((t) => t.id), contains('exam-tomorrow-e'));
    });

    test('nothing to do gives no tips', () {
      expect(
        studentTips(now: now, assignments: [], exams: [], tasks: []),
        isEmpty,
      );
    });
  });

  group('Bus trip', () {
    final route = MockTransport.mansourLine;

    test('before the morning trip', () {
      final trip = simulateTrip(
        route: route,
        now: DateTime(2026, 11, 4, 6, 30),
        isSchoolDay: true,
      );
      expect(trip.phase, TripPhase.notStarted);
      expect(
        describeTrip(trip, DateTime(2026, 11, 4, 6, 30), myStopId: 's4').title,
        'Bus leaves at 06:50',
      );
    });

    test('on the way, counts down to the student\'s stop', () {
      final now = DateTime(2026, 11, 4, 7, 14);
      final trip = simulateTrip(route: route, now: now, isSchoolDay: true);

      expect(trip.phase, TripPhase.onTheWay);
      expect(trip.stops[trip.lastReachedIndex].name, 'Hay Al-Jamia');
      expect(
        describeTrip(trip, now, myStopId: 's4').title,
        'At your stop in 8 min',
      );
    });

    test('afternoon trip runs in reverse from school', () {
      final trip = simulateTrip(
        route: route,
        now: DateTime(2026, 11, 4, 13, 35),
        isSchoolDay: true,
      );
      expect(trip.direction, TripDirection.toHome);
      expect(trip.stops.first.id, 'school');
    });

    test('no trips on days off', () {
      final trip = simulateTrip(
        route: route,
        now: DateTime(2026, 11, 6, 7),
        isSchoolDay: false,
      );
      expect(trip.phase, TripPhase.noTripToday);
    });
  });
}
