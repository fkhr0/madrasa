import '../models/class_timetable_model.dart';
import '../models/period_model.dart';

/// Bell times and the weekly timetable. MockTimetableRepository or
/// ApiTimetableRepository. Failures throw ApiException with a message.
abstract class TimetableRepository {
  Future<List<PeriodModel>> getPeriods();

  /// Replaces the bell times (numbered in list order). Throws ApiException
  /// with status 409 when lessons sit in periods being cut; call again with
  /// [removeLessons] after the user agrees.
  Future<void> savePeriods(
    List<PeriodModel> periods, {
    bool removeLessons = false,
  });

  Future<ClassTimetableModel> getClassTimetable(String classId);

  /// Puts [subjectId] in a period, or changes the lesson there.
  /// Refused when the subject's teacher teaches another class then.
  Future<void> setLesson({
    required String classId,
    required int weekday,
    required int period,
    required String subjectId,
    required String room,
  });

  Future<void> deleteLesson({
    required String classId,
    required int weekday,
    required int period,
  });

  /// A student's class lessons, or a teacher's teaching lessons.
  Future<WeekTimetableModel> getWeek(String personId);
}
