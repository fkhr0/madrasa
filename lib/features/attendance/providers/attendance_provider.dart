import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_summary_model.dart';
import '../models/class_lesson_model.dart';
import '../repo/api_attendance_repository.dart';
import '../repo/attendance_repository.dart';
import '../repo/mock_attendance_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AppConfig.useApi
      ? ApiAttendanceRepository(watchApi(ref))
      : MockAttendanceRepository(),
);

/// Any student's days (the administrator opens them from People).
final studentAttendanceProvider =
    FutureProvider.family<List<AttendanceRecordModel>, String>((
      ref,
      studentId,
    ) {
      ref.watch(authProvider.select((user) => user?.id));
      return ref.watch(attendanceRepositoryProvider).getCurrentTerm(studentId);
    });

/// The signed-in student's days, or the parent's selected child's.
final attendanceRecordsProvider = FutureProvider<List<AttendanceRecordModel>>(
  (ref) => ref.watch(
    studentAttendanceProvider(ref.watch(activeStudentIdProvider)).future,
  ),
);

final attendanceSummaryProvider = FutureProvider<AttendanceSummaryModel>((
  ref,
) async {
  final records = await ref.watch(attendanceRecordsProvider.future);

  return AttendanceSummaryModel.from(records);
});

/// A student's excused days still to come.
final plannedExcusesProvider =
    FutureProvider.family<List<PlannedExcuseModel>, String>(
      (ref, studentId) =>
          ref.watch(attendanceRepositoryProvider).getPlannedExcuses(studentId),
    );

/// The lessons of a class on a day that this user may mark.
final classDayProvider =
    FutureProvider.family<ClassDayModel, (String classId, DateTime date)>(
      (ref, key) =>
          ref.watch(attendanceRepositoryProvider).getClassDay(key.$1, key.$2),
    );

/// The students of one lesson with their marks.
final lessonSheetProvider =
    FutureProvider.family<
      List<StudentMarkModel>,
      (String classId, DateTime date, int period)
    >(
      (ref, key) => ref
          .watch(attendanceRepositoryProvider)
          .getLessonSheet(key.$1, key.$2, key.$3),
    );

final attendanceActionsProvider = Provider<AttendanceActions>(
  AttendanceActions.new,
);

/// Marking lessons and excusing days. Each reloads what it changed.
/// They throw ApiException with a message to show.
class AttendanceActions {
  final Ref _ref;

  AttendanceActions(this._ref);

  AttendanceRepository get _repository =>
      _ref.read(attendanceRepositoryProvider);

  Future<void> saveLessonMarks(
    String classId,
    DateTime date,
    int period,
    Map<String, AttendanceStatus> marks,
  ) async {
    await _repository.saveLessonMarks(classId, date, period, marks);
    _ref
      ..invalidate(classDayProvider((classId, date)))
      ..invalidate(lessonSheetProvider((classId, date, period)))
      ..invalidate(studentAttendanceProvider);
  }

  Future<void> excuseDay(String studentId, DateTime date, String note) async {
    await _repository.excuseDay(studentId, date, note);
    _reloadExcuses(studentId);
  }

  Future<void> removeExcuse(String studentId, DateTime date) async {
    await _repository.removeExcuse(studentId, date);
    _reloadExcuses(studentId);
  }

  void _reloadExcuses(String studentId) => _ref
    ..invalidate(studentAttendanceProvider(studentId))
    ..invalidate(plannedExcusesProvider(studentId));
}
