import 'package:flutter/material.dart';

import '../../academics/models/subject_style.dart';
import 'period_model.dart';

class TimetableLessonModel {
  final int weekday;
  final int period;

  final String start;
  final String end;

  final String subjectId;
  final String subjectName;

  final String iconKey;
  final String colorKey;

  final String? teacherId;
  final String? teacherName;

  final String classId;
  final String className;

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
