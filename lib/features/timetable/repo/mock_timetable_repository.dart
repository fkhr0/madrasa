import '../../../core/network/api_exception.dart';
import '../../academics/data/mock_school_classes.dart';
import '../../academics/models/school_class_model.dart';
import '../models/class_timetable_model.dart';
import '../models/period_model.dart';
import '../models/timetable_lesson_model.dart';
import 'timetable_repository.dart';

/// In-memory timetable for mock mode (lost on reload). 5th A starts with a
/// few lessons so the editor isn't empty; the server checks teacher clashes,
/// this mock doesn't.
class MockTimetableRepository implements TimetableRepository {
  List<PeriodModel> _periods = const [
    PeriodModel(number: 1, start: '08:00', end: '08:45'),
    PeriodModel(number: 2, start: '08:50', end: '09:35'),
    PeriodModel(number: 3, start: '09:40', end: '10:25'),
    PeriodModel(number: 4, start: '10:45', end: '11:30'),
    PeriodModel(number: 5, start: '11:35', end: '12:20'),
    PeriodModel(number: 6, start: '12:25', end: '13:10'),
  ];

  static const _workingDays = [7, 1, 2, 3, 4];

  /// (class, weekday, period) → (subject, room)
  final Map<(String, int, int), (String, String)> _slots = {
    ('cls-5a', 7, 1): ('islamic', 'Room 204'),
    ('cls-5a', 7, 2): ('math', 'Room 204'),
    ('cls-5a', 7, 3): ('physics', 'Lab 2'),
    ('cls-5a', 1, 1): ('chemistry', 'Lab 1'),
    ('cls-5a', 1, 2): ('math', 'Room 204'),
  };

  final List<SchoolClassModel> _classes = MockSchoolClasses.classes;

  @override
  Future<List<PeriodModel>> getPeriods() async => _periods;

  @override
  Future<void> savePeriods(
    List<PeriodModel> periods, {
    bool removeLessons = false,
  }) async {
    final cut = _slots.keys.where((k) => k.$3 > periods.length).toList();
    if (cut.isNotEmpty && !removeLessons) {
      throw ApiException(
        '${cut.length} lessons are placed after period ${periods.length}. '
        'Remove them too?',
        status: 409,
      );
    }
    cut.forEach(_slots.remove);
    _periods = [
      for (var i = 0; i < periods.length; i++)
        PeriodModel(
          number: i + 1,
          start: periods[i].start,
          end: periods[i].end,
        ),
    ];
  }

  @override
  Future<ClassTimetableModel> getClassTimetable(String classId) async =>
      ClassTimetableModel(
        periods: _periods,
        workingDays: _workingDays,
        lessons: _lessons((k) => k.$1 == classId),
      );

  @override
  Future<void> setLesson({
    required String classId,
    required int weekday,
    required int period,
    required String subjectId,
    required String room,
  }) async => _slots[(classId, weekday, period)] = (subjectId, room);

  @override
  Future<void> deleteLesson({
    required String classId,
    required int weekday,
    required int period,
  }) async => _slots.remove((classId, weekday, period));

  @override
  Future<WeekTimetableModel> getWeek(String personId) async =>
      WeekTimetableModel(
        periods: _periods,
        lessons: personId.startsWith('STU')
            ? _lessons((k) => k.$1 == 'cls-5a')
            : _lessons(
                (_) => true,
              ).where((l) => l.teacherId == personId).toList(),
      );

  List<TimetableLessonModel> _lessons(bool Function((String, int, int)) where) {
    final subjects = {for (final s in MockSchoolClasses.subjects) s.id: s};
    final lessons = <TimetableLessonModel>[];

    for (final MapEntry(key: slot, value: (subjectId, room))
        in _slots.entries) {
      final (classId, weekday, period) = slot;
      if (!where(slot) || period > _periods.length) continue;
      final schoolClass = _classes.firstWhere((c) => c.id == classId);
      final teaching = schoolClass.subjects
          .where((s) => s.subjectId == subjectId)
          .firstOrNull;
      final subject = subjects[subjectId]!;
      final bell = _periods[period - 1];

      lessons.add(
        TimetableLessonModel(
          weekday: weekday,
          period: period,
          start: bell.start,
          end: bell.end,
          subjectId: subjectId,
          subjectName: subject.name,
          iconKey: subject.iconKey,
          colorKey: subject.colorKey,
          teacherId: teaching?.teacherId,
          teacherName: teaching?.teacherName,
          classId: classId,
          className: schoolClass.name,
          room: room,
        ),
      );
    }

    return lessons..sort(
      (a, b) => (a.weekday * 100 + a.period) - (b.weekday * 100 + b.period),
    );
  }
}
