import '../../../core/utils/day_json.dart';
import '../../academics/data/mock_school_classes.dart';
import '../../schedule/data/mock_schedule.dart';
import '../../teaching/data/mock_teaching.dart';
import '../data/mock_attendance.dart';
import '../models/attendance_record_model.dart';
import '../models/class_lesson_model.dart';
import 'attendance_repository.dart';

/// In-memory attendance for mock mode (lost on reload). Lessons come from
/// Mr. Ahmed's mock timetable.
class MockAttendanceRepository implements AttendanceRepository {
  /// "cls-5a/2026-11-08/2" → student ID → status.
  final _marks = <String, Map<String, AttendanceStatus>>{};

  /// "STU-.../2026-11-08" → note.
  final _excuses = <String, String>{};

  @override
  Future<List<AttendanceRecordModel>> getCurrentTerm(String studentId) async =>
      [
        for (final r in MockAttendance.forStudent(studentId))
          if (_excuses['$studentId/${formatDay(r.date)}'] case final note?)
            AttendanceRecordModel(
              date: r.date,
              status: AttendanceStatus.excused,
              note: note.isEmpty ? 'Excused by the school' : note,
            )
          else
            r,
      ];

  @override
  Future<ClassDayModel> getClassDay(String classId, DateTime date) async {
    final className = MockSchoolClasses.classes
        .firstWhere((c) => c.id == classId)
        .name;
    final isSchoolDay =
        date.weekday != DateTime.friday && date.weekday != DateTime.saturday;

    return ClassDayModel(
      date: date,
      className: className,
      isSchoolDay: isSchoolDay,
      lessons: [
        if (isSchoolDay)
          for (final l in MockSchedule.teacherLessonsFor(date))
            if (l.className == className)
              ClassLessonModel(
                period: MockSchedule.periodOf(l.start),
                start: _time(l.start),
                end: _time(l.end),
                subjectName: l.subject.name,
                teacherName: l.subject.teacherName,
                taken: _marks.containsKey(
                  _key(classId, date, MockSchedule.periodOf(l.start)),
                ),
              ),
      ],
    );
  }

  @override
  Future<List<StudentMarkModel>> getLessonSheet(
    String classId,
    DateTime date,
    int period,
  ) async {
    final marks = _marks[_key(classId, date, period)] ?? const {};

    return [
      for (final s in MockTeaching.studentsOf(classId))
        StudentMarkModel(id: s.id, name: s.name, status: marks[s.id]),
    ];
  }

  @override
  Future<void> saveLessonMarks(
    String classId,
    DateTime date,
    int period,
    Map<String, AttendanceStatus> marks,
  ) async => _marks[_key(classId, date, period)] = {...marks};

  @override
  Future<void> excuseDay(String studentId, DateTime date, String note) async =>
      _excuses['$studentId/${formatDay(date)}'] = note;

  @override
  Future<void> removeExcuse(String studentId, DateTime date) async =>
      _excuses.remove('$studentId/${formatDay(date)}');

  @override
  Future<List<PlannedExcuseModel>> getPlannedExcuses(String studentId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (final MapEntry(:key, :value) in _excuses.entries)
        if (key.startsWith('$studentId/'))
          if (parseDay(key.split('/').last) case final day
              when day.isAfter(today))
            PlannedExcuseModel(date: day, note: value),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  static String _key(String classId, DateTime date, int period) =>
      '$classId/${formatDay(date)}/$period';

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
