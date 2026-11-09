import '../data/mock_schedule.dart';
import '../models/lesson_model.dart';
import 'schedule_repository.dart';

class MockScheduleRepository implements ScheduleRepository {
  const MockScheduleRepository();

  @override
  Future<List<LessonModel>> getLessonsFor(String personId, DateTime day) async {
    if (personId.startsWith('TCH')) return MockSchedule.teacherLessonsFor(day);
    if (personId.startsWith('DRV') || personId.startsWith('ADM')) return [];

    return MockSchedule.lessonsFor(day);
  }
}
