import '../models/lesson_model.dart';

/// Today: MockScheduleRepository. Backend stage: ApiScheduleRepository.
abstract class ScheduleRepository {
  /// Lessons of [day] for [personId] (a student, or a teacher's teaching
  /// timetable), sorted by start time.
  Future<List<LessonModel>> getLessonsFor(String personId, DateTime day);
}
