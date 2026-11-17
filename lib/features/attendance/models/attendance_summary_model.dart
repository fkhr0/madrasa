import 'attendance_record_model.dart';

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

  double? get rate {
    if (totalDays == 0) return null;
    return (present + late) / totalDays * 100;
  }
}
