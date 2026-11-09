import 'package:flutter/material.dart';

import '../../academics/models/subject_style.dart';
import 'period_model.dart';

/// One lesson in the weekly timetable: a class has a subject in a period of
/// a study day. The teacher is whoever teaches that subject in that class.
class TimetableLessonModel {
  /// DateTime.monday (1) ... DateTime.sunday (7).
  final int weekday;
  final int period;

  /// "08:50", from the bell times.
  final String start;
  final String end;

  final String subjectId;
  final String subjectName;

  /// Keys from [SubjectStyle], e.g. "math" and "purple".
  final String iconKey;
  final String colorKey;

  /// Null while the class has no teacher for the subject.
  final String? teacherId;
  final String? teacherName;

  final String classId;
  final String className;

  /// Empty when not set.
  final String room;

  const TimetableLessonModel({
    required this.weekday,
    required this.period,
    required this.start,
    required this.end,
    required this.subjectId,
    required this.subjectName,
    required this.iconKey,
    required this.colorKey,
    this.teacherId,
    this.teacherName,
    required this.classId,
    required this.className,
    this.room = '',
  });

  /// Its bell period, e.g. to get the start time on a given day.
  PeriodModel get bell => PeriodModel(number: period, start: start, end: end);

  IconData get icon => SubjectStyle.icon(iconKey);

  Color get color => SubjectStyle.color(colorKey);

  factory TimetableLessonModel.fromJson(Map<String, dynamic> json) =>
      TimetableLessonModel(
        weekday: json['weekday'] as int,
        period: json['period'] as int,
        start: json['start'] as String,
        end: json['end'] as String,
        subjectId: json['subjectId'] as String,
        subjectName: json['subjectName'] as String,
        iconKey: json['icon'] as String? ?? 'book',
        colorKey: json['color'] as String? ?? 'blue',
        teacherId: json['teacherId'] as String?,
        teacherName: json['teacherName'] as String?,
        classId: json['classId'] as String,
        className: json['className'] as String,
        room: json['room'] as String? ?? '',
      );
}
