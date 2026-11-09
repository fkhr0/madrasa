import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/network/api_exception.dart';
import 'package:school/features/schedule/repo/api_schedule_repository.dart';
import 'package:school/features/timetable/models/class_timetable_model.dart';
import 'package:school/features/timetable/models/period_model.dart';
import 'package:school/features/timetable/repo/mock_timetable_repository.dart';

/// The server's week for a teacher: maths in 5th A on Sunday, 6th C on Monday.
const _json = {
  'periods': [
    {'number': 1, 'start': '08:00', 'end': '08:45'},
    {'number': 2, 'start': '08:50', 'end': '09:35'},
  ],
  'lessons': [
    {
      'weekday': 7,
      'period': 2,
      'start': '08:50',
      'end': '09:35',
      'subjectId': 'math',
      'subjectName': 'Mathematics',
      'icon': 'math',
      'color': 'purple',
      'teacherId': 'TCH-2019-0031',
      'teacherName': 'Ahmed Kareem',
      'classId': 'cls-5a',
      'className': '5th Scientific – A',
      'room': 'Room 204',
    },
    {
      'weekday': 1,
      'period': 1,
      'start': '08:00',
      'end': '08:45',
      'subjectId': 'math',
      'subjectName': 'Mathematics',
      'icon': 'math',
      'color': 'purple',
      'teacherId': 'TCH-2019-0031',
      'teacherName': 'Ahmed Kareem',
      'classId': 'cls-6c',
      'className': '6th Scientific – C',
      'room': '',
    },
  ],
};

class _CountingTimetable extends MockTimetableRepository {
  int requests = 0;

  @override
  Future<WeekTimetableModel> getWeek(String personId) async {
    requests++;
    return WeekTimetableModel.fromJson(_json);
  }
}

void main() {
  test('the server week becomes lessons of a given day', () async {
    final timetable = _CountingTimetable();
    final schedule = ApiScheduleRepository(timetable);
    final sunday = DateTime(2026, 11, 8);

    final lessons = await schedule.getLessonsFor('TCH-2019-0031', sunday);

    expect(lessons, hasLength(1));
    expect(lessons.single.subject.name, 'Mathematics');
    expect(lessons.single.start, DateTime(2026, 11, 8, 8, 50));
    expect(lessons.single.end, DateTime(2026, 11, 8, 9, 35));
    expect(lessons.single.className, '5th Scientific – A');

    // Monday comes from the same week: no second request.
    final monday = await schedule.getLessonsFor(
      'TCH-2019-0031',
      DateTime(2026, 11, 9),
    );
    expect(monday.single.className, '6th Scientific – C');
    expect(timetable.requests, 1);
  });

  test('a period knows its times on a day', () {
    const period = PeriodModel(number: 4, start: '10:45', end: '11:30');

    expect(period.label, '10:45 – 11:30');
    expect(
      period.startOn(DateTime(2026, 11, 8)),
      DateTime(2026, 11, 8, 10, 45),
    );
    expect(period.endMinutes - period.startMinutes, 45);
  });

  test('mock: cutting periods with lessons asks first', () async {
    final repo = MockTimetableRepository();
    final two = (await repo.getPeriods()).take(2).toList();

    // 5th A has a lesson in period 3 on Sunday.
    await expectLater(
      repo.savePeriods(two),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
    await repo.savePeriods(two, removeLessons: true);

    final week = await repo.getClassTimetable('cls-5a');
    expect(week.periods, hasLength(2));
    expect(week.lessons.every((l) => l.period <= 2), isTrue);
    expect(week.days.first, DateTime.sunday);
  });
}
