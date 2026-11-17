import '../models/attendance_record_model.dart';
import '../models/class_lesson_model.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecordModel>> getCurrentTerm(String studentId);

  Future<ClassDayModel> getClassDay(String classId, DateTime date);

  Future<List<StudentMarkModel>> getLessonSheet(
    String classId,
    DateTime date,
    int period,
  );

  Future<void> saveLessonMarks(
    String classId,
    DateTime date,
    int period,
    Map<String, AttendanceStatus> marks,
  );

  Future<void> excuseDay(String studentId, DateTime date, String note);

  Future<List<PlannedExcuseModel>> getPlannedExcuses(String studentId);

  Future<void> removeExcuse(String studentId, DateTime date);
}
