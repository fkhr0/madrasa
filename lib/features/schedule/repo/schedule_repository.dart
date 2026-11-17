import '../models/lesson_model.dart';

abstract class ScheduleRepository {
  Future<List<LessonModel>> getLessonsFor(String personId, DateTime day);
}
