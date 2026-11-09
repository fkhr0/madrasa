import '../../subjects/data/mock_subjects.dart';
import '../../subjects/models/subject_model.dart';
import '../models/lesson_model.dart';

/// Fake weekly timetable. School week is Sunday → Thursday.
class MockSchedule {
  MockSchedule._();

  /// Period start times (hour, minute). Every period is 45 minutes.
  static const _periods = [
    (8, 0),
    (8, 50),
    (9, 40),
    (10, 45),
    (11, 35),
    (12, 25),
  ];

  /// Subjects per weekday. Keys use DateTime.monday ... DateTime.sunday.
  static const Map<int, List<(SubjectModel, String)>> _week = {
    DateTime.sunday: [
      (MockSubjects.islamic, 'Room 204'),
      (MockSubjects.math, 'Room 204'),
      (MockSubjects.physics, 'Lab 2'),
      (MockSubjects.arabic, 'Room 204'),
      (MockSubjects.english, 'Room 110'),
      (MockSubjects.biology, 'Lab 3'),
    ],
    DateTime.monday: [
      (MockSubjects.chemistry, 'Lab 1'),
      (MockSubjects.math, 'Room 204'),
      (MockSubjects.computer, 'Computer Lab'),
      (MockSubjects.arabic, 'Room 204'),
      (MockSubjects.english, 'Room 110'),
      (MockSubjects.physics, 'Lab 2'),
    ],
    DateTime.tuesday: [
      (MockSubjects.english, 'Room 110'),
      (MockSubjects.math, 'Room 204'),
      (MockSubjects.biology, 'Lab 3'),
      (MockSubjects.chemistry, 'Lab 1'),
      (MockSubjects.arabic, 'Room 204'),
    ],
    DateTime.wednesday: [
      (MockSubjects.physics, 'Lab 2'),
      (MockSubjects.computer, 'Computer Lab'),
      (MockSubjects.math, 'Room 204'),
      (MockSubjects.english, 'Room 110'),
      (MockSubjects.chemistry, 'Lab 1'),
      (MockSubjects.arabic, 'Room 204'),
    ],
    DateTime.thursday: [
      (MockSubjects.arabic, 'Room 204'),
      (MockSubjects.islamic, 'Room 204'),
      (MockSubjects.math, 'Room 204'),
      (MockSubjects.computer, 'Computer Lab'),
    ],
  };

  /// Mr. Ahmed Kareem's maths classes. Null = free period.
  static const Map<int, List<(String, String)?>> _teacherWeek = {
    DateTime.sunday: [
      null,
      ('5th Scientific – A', 'Room 204'),
      ('5th Scientific – B', 'Room 206'),
      null,
      ('4th Scientific – A', 'Room 105'),
    ],
    DateTime.monday: [
      ('6th Scientific – C', 'Room 301'),
      ('5th Scientific – A', 'Room 204'),
      null,
      ('5th Scientific – B', 'Room 206'),
    ],
    DateTime.tuesday: [
      ('4th Scientific – A', 'Room 105'),
      ('5th Scientific – A', 'Room 204'),
      ('6th Scientific – C', 'Room 301'),
      null,
      ('5th Scientific – B', 'Room 206'),
    ],
    DateTime.wednesday: [
      ('5th Scientific – B', 'Room 206'),
      null,
      ('5th Scientific – A', 'Room 204'),
      ('6th Scientific – C', 'Room 301'),
      ('4th Scientific – A', 'Room 105'),
    ],
    DateTime.thursday: [
      null,
      ('6th Scientific – C', 'Room 301'),
      ('5th Scientific – A', 'Room 204'),
    ],
  };

  static List<LessonModel> teacherLessonsFor(DateTime day) {
    final periods = _teacherWeek[day.weekday] ?? [];
    final lessons = <LessonModel>[];

    for (var i = 0; i < periods.length; i++) {
      final period = periods[i];
      if (period == null) continue; // free period

      lessons.add(
        LessonModel(
          id: 't-${day.year}${day.month}${day.day}-$i',
          subject: MockSubjects.math,
          room: period.$2,
          className: period.$1,
          start: _at(day, i),
          end: _at(day, i).add(const Duration(minutes: 45)),
        ),
      );
    }

    return lessons;
  }

  /// The period number (1, 2, 3...) of a lesson starting at [start].
  static int periodOf(DateTime start) =>
      _periods.indexOf((start.hour, start.minute)) + 1;

  static DateTime _at(DateTime day, int period) => DateTime(
    day.year,
    day.month,
    day.day,
    _periods[period].$1,
    _periods[period].$2,
  );

  static List<LessonModel> lessonsFor(DateTime day) {
    final subjects = _week[day.weekday] ?? [];

    return [
      for (var i = 0; i < subjects.length; i++)
        LessonModel(
          id: '${day.year}${day.month}${day.day}-$i',
          subject: subjects[i].$1,
          room: subjects[i].$2,
          start: DateTime(
            day.year,
            day.month,
            day.day,
            _periods[i].$1,
            _periods[i].$2,
          ),
          end: DateTime(
            day.year,
            day.month,
            day.day,
            _periods[i].$1,
            _periods[i].$2,
          ).add(const Duration(minutes: 45)),
        ),
    ];
  }
}
