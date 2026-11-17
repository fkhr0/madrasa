import '../models/class_timetable_model.dart';
import '../models/period_model.dart';

abstract class TimetableRepository {
  Future<List<PeriodModel>> getPeriods();

  Future<void> savePeriods(
    List<PeriodModel> periods, {
    bool removeLessons = false,
  });

  Future<ClassTimetableModel> getClassTimetable(String classId);

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

  Future<WeekTimetableModel> getWeek(String personId);
}
