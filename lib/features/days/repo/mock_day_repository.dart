import '../../../core/utils/date_formatter.dart';
import '../../schedule/data/mock_schedule.dart';
import '../../schedule/models/lesson_model.dart';
import '../models/day_model.dart';
import 'day_repository.dart';

/// Mock mode: the day's lessons from the mock timetable, nothing taken yet.
class MockDayRepository implements DayRepository {
  const MockDayRepository();

  static bool _isSchoolDay(DateTime d) =>
      d.weekday != DateTime.friday && d.weekday != DateTime.saturday;

  DayModel _day(DateTime date, List<LessonModel> lessons, {String? who}) {
    final now = DateTime.now();
    final school = _isSchoolDay(date);
    return DayModel(
      date: date,
      isToday: DateFormatter.isSameDay(date, now),
      isSchoolDay: school,
      dayOff: school ? null : 'Weekend',
      studentName: who,
      periods: [
        if (school)
          for (final l in lessons)
            DayPeriodModel(
              number: MockSchedule.periodOf(l.start),
              start: DateFormatter.time(l.start),
              end: DateFormatter.time(l.end),
              state: now.isAfter(l.end)
                  ? PeriodState.done
                  : now.isAfter(l.start)
                  ? PeriodState.now
                  : PeriodState.later,
              lessons: [
                DayLessonModel(
                  classId: 'cls-5a',
                  className: l.className ?? '5th Scientific – A',
                  subjectName: l.subject.name,
                  teacherName: l.subject.teacherName,
                  room: l.room,
                ),
              ],
            ),
      ],
    );
  }

  @override
  Future<DayModel> getSchoolDay(DateTime date) async =>
      _day(date, MockSchedule.lessonsFor(date));

  @override
  Future<DayModel> getTeacherDay(DateTime date) async =>
      _day(date, MockSchedule.teacherLessonsFor(date));

  @override
  Future<DayModel> getStudentDay(String studentId, DateTime date) async =>
      _day(date, MockSchedule.lessonsFor(date), who: 'Zainab Haider');
}
