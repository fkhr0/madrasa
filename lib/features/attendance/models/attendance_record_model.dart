import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/day_json.dart';
import '../../../core/l10n/language.dart';

enum AttendanceStatus {
  present,
  late,
  absent,
  excused;

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return tr('Present');
      case AttendanceStatus.late:
        return tr('Late');
      case AttendanceStatus.absent:
        return tr('Absent');
      case AttendanceStatus.excused:
        return tr('Excused');
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.late:
        return AppColors.warning;
      case AttendanceStatus.absent:
        return AppColors.danger;
      case AttendanceStatus.excused:
        return AppColors.info;
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.present:
        return Icons.check_circle_outline;
      case AttendanceStatus.late:
        return Icons.schedule;
      case AttendanceStatus.absent:
        return Icons.cancel_outlined;
      case AttendanceStatus.excused:
        return Icons.verified_outlined;
    }
  }
}

/// A day the office excused ahead (a planned absence).
class PlannedExcuseModel {
  final DateTime date;
  final String note;

  const PlannedExcuseModel({required this.date, this.note = ''});

  factory PlannedExcuseModel.fromJson(Map<String, dynamic> json) =>
      PlannedExcuseModel(
        date: parseDay(json['date'] as String),
        note: json['note'] as String? ?? '',
      );
}

/// How a student was marked in one lesson of a day.
class LessonMarkModel {
  final int period;
  final String subjectName;
  final AttendanceStatus status;

  const LessonMarkModel({
    required this.period,
    required this.subjectName,
    required this.status,
  });

  factory LessonMarkModel.fromJson(Map<String, dynamic> json) =>
      LessonMarkModel(
        period: json['period'] as int,
        subjectName: json['subjectName'] as String,
        status: AttendanceStatus.values.byName(json['status'] as String),
      );
}

/// Attendance for one school day.
class AttendanceRecordModel {
  final DateTime date;
  final AttendanceStatus status;

  /// e.g. "Late to Mathematics" or "Medical note received".
  final String? note;

  /// Each lesson's mark (empty in mock data).
  final List<LessonMarkModel> lessons;

  const AttendanceRecordModel({
    required this.date,
    required this.status,
    this.note,
    this.lessons = const [],
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel(
        date: parseDay(json['date'] as String),
        status: AttendanceStatus.values.byName(json['status'] as String),
        note: json['note'] as String?,
        lessons: [
          for (final l in json['lessons'] as List? ?? const [])
            LessonMarkModel.fromJson(l as Map<String, dynamic>),
        ],
      );
}
