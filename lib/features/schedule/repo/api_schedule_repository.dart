import '../../subjects/models/subject_model.dart';
import '../../timetable/models/class_timetable_model.dart';
import '../../timetable/repo/timetable_repository.dart';
import '../models/lesson_model.dart';
import 'schedule_repository.dart';
import '../../../core/l10n/language.dart';

/// Day schedules from the weekly timetable on the server. The week is kept
/// for a minute, so a screen asking for several days makes one request.
class ApiScheduleRepository implements ScheduleRepository {
  final TimetableRepository _timetable;

  ApiScheduleRepository(this._timetable);

  static const _keepFor = Duration(minutes: 1);
  final _weeks = <String, (DateTime, Future<WeekTimetableModel>)>{};

  @override
  Future<List<LessonModel>> getLessonsFor(String personId, DateTime day) async {
    final week = await _week(personId);

    return [
      for (final lesson in week.lessonsOn(day.weekday))
        LessonModel(
          id: '${lesson.classId}-${day.year}${day.month}${day.day}-${lesson.period}',
          subject: SubjectModel(
            id: lesson.subjectId,
            name: lesson.subjectName,
            teacherName: lesson.teacherName ?? tr('No teacher yet'),
            icon: lesson.icon,
            color: lesson.color,
          ),
          room: lesson.room,
          start: lesson.bell.startOn(day),
          end: lesson.bell.endOn(day),
          // Only a teacher's week spans several classes.
          className: personId.startsWith('TCH') ? lesson.className : null,
        ),
    ];
  }

  Future<WeekTimetableModel> _week(String personId) {
    final now = DateTime.now();
    final kept = _weeks[personId];
    if (kept != null && now.difference(kept.$1) < _keepFor) return kept.$2;

    final week = _timetable.getWeek(personId);
    _weeks[personId] = (now, week);
    // A failed request isn't kept: the next try asks again.
    week.catchError((Object _) {
      _weeks.remove(personId);
      return const WeekTimetableModel(periods: [], lessons: []);
    });
    return week;
  }
}
