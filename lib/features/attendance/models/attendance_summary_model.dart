import 'attendance_record_model.dart';

/// Totals calculated from a list of records.
class AttendanceSummaryModel {
  final int present;
  final int late;
  final int absent;
  final int excused;

  const AttendanceSummaryModel({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
  });

  factory AttendanceSummaryModel.from(List<AttendanceRecordModel> records) {
    int count(AttendanceStatus status) =>
        records.where((r) => r.status == status).length;

    return AttendanceSummaryModel(
      present: count(AttendanceStatus.present),
      late: count(AttendanceStatus.late),
      absent: count(AttendanceStatus.absent),
      excused: count(AttendanceStatus.excused),
    );
  }

  int get totalDays => present + late + absent + excused;

  /// Days the student was at school (late still counts), as 0–100; null
  /// before the first day is recorded.
  double? get rate {
    if (totalDays == 0) return null;
    return (present + late) / totalDays * 100;
  }
}
