import '../models/day_model.dart';

abstract class DayRepository {
  Future<DayModel> getSchoolDay(DateTime date);

  Future<DayModel> getTeacherDay(DateTime date);

  Future<DayModel> getStudentDay(String studentId, DateTime date);
}
