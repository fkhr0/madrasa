import '../../subjects/models/subject_model.dart';
import '../../timetable/models/class_timetable_model.dart';
import '../../timetable/repo/timetable_repository.dart';
import '../models/lesson_model.dart';
import 'schedule_repository.dart';
import '../../../core/l10n/language.dart';

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
    week.catchError((Object _) {
      _weeks.remove(personId);
      return const WeekTimetableModel(periods: [], lessons: []);
    });
    return week;
  }
}
