import '../models/attendance_record_model.dart';
import '../models/class_lesson_model.dart';

/// MockAttendanceRepository or ApiAttendanceRepository. Failures throw
/// ApiException with a message to show.
abstract class AttendanceRepository {
  /// Days of the current term for [studentId], newest first. Only days
  /// where attendance was taken (or the school excused).
  Future<List<AttendanceRecordModel>> getCurrentTerm(String studentId);

  // ---------- Taking attendance (teacher of the lesson, or administrator) ----------

  /// The lessons of [classId] on [date] this user may mark.
  Future<ClassDayModel> getClassDay(String classId, DateTime date);

  /// The students of one lesson, with their marks if already taken.
  Future<List<StudentMarkModel>> getLessonSheet(
    String classId,
    DateTime date,
    int period,
  );

  /// One status per student ID; every student of the class is marked.
  Future<void> saveLessonMarks(
    String classId,
    DateTime date,
    int period,
    Map<String, AttendanceStatus> marks,
  );

  // ---------- Excused days (administrator) ----------

  /// Also for a day ahead (a planned absence): teachers still mark it,
  /// but the family isn't alerted and the day counts as excused.
  Future<void> excuseDay(String studentId, DateTime date, String note);

  /// Excused days still to come, soonest first.
  Future<List<PlannedExcuseModel>> getPlannedExcuses(String studentId);

  Future<void> removeExcuse(String studentId, DateTime date);
}
