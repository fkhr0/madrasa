import '../../auth/data/mock_users.dart';
import '../models/attendance_record_model.dart';

class MockAttendance {
  MockAttendance._();

  static List<AttendanceRecordModel> forStudent(String studentId) =>
      _records(studentId == MockUsers.secondStudent.id ? _ali : _zainab);

  static const _ali = {
    1: (AttendanceStatus.absent, null),
    5: (AttendanceStatus.late, 'Arrived 08:25'),
    6: (AttendanceStatus.late, 'Arrived 08:15'),
    13: (AttendanceStatus.absent, null),
    20: (AttendanceStatus.absent, null),
  };

  /// School days ago → a record that is not "present". Every other school
  /// day is present. Counted in school days so they never fall on a weekend.
  static const _zainab = {
    2: (AttendanceStatus.late, 'Arrived 08:20'),
    9: (AttendanceStatus.absent, null),
    15: (AttendanceStatus.excused, 'Medical note received'),
    16: (AttendanceStatus.excused, 'Medical note received'),
    23: (AttendanceStatus.late, 'Arrived 08:10'),
  };

  /// The last 40 calendar days, skipping Friday and Saturday.
  static List<AttendanceRecordModel> _records(
    Map<int, (AttendanceStatus, String?)> exceptions,
  ) {
    final today = DateTime.now();
    final result = <AttendanceRecordModel>[];
    var schoolDaysAgo = 0;

    for (var daysAgo = 1; daysAgo <= 40; daysAgo++) {
      final date = DateTime(today.year, today.month, today.day - daysAgo);
      if (date.weekday == DateTime.friday ||
          date.weekday == DateTime.saturday) {
        continue;
      }
      schoolDaysAgo++;

      final exception = exceptions[schoolDaysAgo];
      result.add(
        AttendanceRecordModel(
          date: date,
          status: exception?.$1 ?? AttendanceStatus.present,
          note: exception?.$2,
        ),
      );
    }

    return result;
  }
}
