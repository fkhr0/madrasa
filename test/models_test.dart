import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/utils/date_formatter.dart';
import 'package:school/features/attendance/models/attendance_record_model.dart';
import 'package:school/features/attendance/models/attendance_summary_model.dart';
import 'package:school/features/grades/models/grade_item_model.dart';
import 'package:school/features/grades/models/subject_grades_model.dart';
import 'package:school/features/subjects/data/mock_subjects.dart';

void main() {
  group('DateFormatter.dueLabel', () {
    final now = DateTime.now();
    DateTime inDays(int days) => DateTime(now.year, now.month, now.day + days);

    test('today, tomorrow, future and overdue', () {
      expect(DateFormatter.dueLabel(inDays(0)), 'Due today');
      expect(DateFormatter.dueLabel(inDays(1)), 'Due tomorrow');
      expect(DateFormatter.dueLabel(inDays(4)), 'Due in 4 days');
      expect(DateFormatter.dueLabel(inDays(-1)), '1 day overdue');
      expect(DateFormatter.dueLabel(inDays(-3)), '3 days overdue');
    });
  });

  group('AttendanceSummaryModel', () {
    test('late counts as attended, absent and excused do not', () {
      final day = DateTime(2026, 11, 1);
      final summary = AttendanceSummaryModel.from([
        AttendanceRecordModel(date: day, status: AttendanceStatus.present),
        AttendanceRecordModel(date: day, status: AttendanceStatus.late),
        AttendanceRecordModel(date: day, status: AttendanceStatus.absent),
        AttendanceRecordModel(date: day, status: AttendanceStatus.excused),
      ]);

      expect(summary.totalDays, 4);
      expect(summary.rate, 50);
    });

    test('no records means no rate yet', () {
      expect(AttendanceSummaryModel.from([]).rate, isNull);
    });
  });

  group('SubjectGradesModel.average', () {
    test('is weighted by max score', () {
      final date = DateTime(2026, 11, 1);
      final grades = SubjectGradesModel(
        subject: MockSubjects.math,
        items: [
          GradeItemModel(
            title: 'Quiz',
            category: 'Quiz',
            score: 10,
            maxScore: 10,
            date: date,
          ),
          GradeItemModel(
            title: 'Test',
            category: 'Test',
            score: 20,
            maxScore: 40,
            date: date,
          ),
        ],
      );

      // (10 + 20) / (10 + 40) = 60%
      expect(grades.average, closeTo(60, 0.001));
    });
  });
}
