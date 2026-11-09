import '../../../core/network/api_client.dart';
import '../../../core/utils/day_json.dart';
import '../models/attendance_record_model.dart';
import '../models/class_lesson_model.dart';
import 'attendance_repository.dart';

/// Attendance on the school API (server/src/features/attendance).
class ApiAttendanceRepository implements AttendanceRepository {
  final ApiClient _api;

  const ApiAttendanceRepository(this._api);

  @override
  Future<List<AttendanceRecordModel>> getCurrentTerm(String studentId) async {
    final json = await _api.get('/attendance/students/$studentId') as Map;

    return [
      for (final day in json['days'] as List)
        AttendanceRecordModel.fromJson(day as Map<String, dynamic>),
    ];
  }

  @override
  Future<ClassDayModel> getClassDay(String classId, DateTime date) async =>
      ClassDayModel.fromJson(
        await _api.get(
              '/attendance/classes/$classId/lessons?date=${formatDay(date)}',
            )
            as Map<String, dynamic>,
      );

  @override
  Future<List<StudentMarkModel>> getLessonSheet(
    String classId,
    DateTime date,
    int period,
  ) async {
    final json = await _api.get(_lesson(classId, date, period)) as Map;

    return [
      for (final s in json['students'] as List)
        StudentMarkModel.fromJson(s as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> saveLessonMarks(
    String classId,
    DateTime date,
    int period,
    Map<String, AttendanceStatus> marks,
  ) => _api.put(_lesson(classId, date, period), {
    'marks': {for (final e in marks.entries) e.key: e.value.name},
  });

  @override
  Future<void> excuseDay(String studentId, DateTime date, String note) =>
      _api.put('/attendance/students/$studentId/excuses/${formatDay(date)}', {
        'note': note,
      });

  @override
  Future<void> removeExcuse(String studentId, DateTime date) =>
      _api.delete('/attendance/students/$studentId/excuses/${formatDay(date)}');

  @override
  Future<List<PlannedExcuseModel>> getPlannedExcuses(String studentId) async =>
      [
        for (final json
            in await _api.get('/attendance/students/$studentId/excuses/planned')
                as List)
          PlannedExcuseModel.fromJson(json as Map<String, dynamic>),
      ];

  static String _lesson(String classId, DateTime date, int period) =>
      '/attendance/classes/$classId/lessons/${formatDay(date)}/$period';
}
