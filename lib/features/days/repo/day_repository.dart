import '../models/day_model.dart';

/// A day at school as each role sees it. MockDayRepository or
/// ApiDayRepository. Failures throw ApiException with a message.
abstract class DayRepository {
  /// Office: every period and class, who took attendance, the day's totals.
  Future<DayModel> getSchoolDay(DateTime date);

  /// The signed-in teacher's lessons, homework due and exams.
  Future<DayModel> getTeacherDay(DateTime date);

  /// A student's own lessons and marks, homework, exams and bus.
  Future<DayModel> getStudentDay(String studentId, DateTime date);
}
