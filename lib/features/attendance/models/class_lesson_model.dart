import '../../../core/utils/day_json.dart';
import 'attendance_record_model.dart';

/// A lesson of a class on one day that this user may mark.
class ClassLessonModel {
  final int period;

  /// "08:50"
  final String start;
  final String end;
  final String subjectName;
  final String? teacherName;

  /// Attendance was already taken (it can still be corrected).
  final bool taken;

  const ClassLessonModel({
    required this.period,
    required this.start,
    required this.end,
    required this.subjectName,
    this.teacherName,
    this.taken = false,
  });

  factory ClassLessonModel.fromJson(Map<String, dynamic> json) =>
      ClassLessonModel(
        period: json['period'] as int,
        start: json['start'] as String,
        end: json['end'] as String,
        subjectName: json['subjectName'] as String,
        teacherName: json['teacherName'] as String?,
        taken: json['taken'] as bool? ?? false,
      );
}

/// A class's day: the lessons this user may mark.
class ClassDayModel {
  final DateTime date;
  final String className;

  /// False on weekends, holidays and outside the study year.
  final bool isSchoolDay;
  final List<ClassLessonModel> lessons;

  const ClassDayModel({
    required this.date,
    required this.className,
    required this.isSchoolDay,
    required this.lessons,
  });

  factory ClassDayModel.fromJson(Map<String, dynamic> json) => ClassDayModel(
    date: parseDay(json['date'] as String),
    className: json['className'] as String,
    isSchoolDay: json['isSchoolDay'] as bool,
    lessons: [
      for (final l in json['lessons'] as List)
        ClassLessonModel.fromJson(l as Map<String, dynamic>),
    ],
  );
}

/// A student on the attendance sheet of one lesson.
class StudentMarkModel {
  final String id;
  final String name;

  /// Null while attendance hasn't been taken for this lesson.
  final AttendanceStatus? status;

  const StudentMarkModel({required this.id, required this.name, this.status});

  factory StudentMarkModel.fromJson(Map<String, dynamic> json) =>
      StudentMarkModel(
        id: json['id'] as String,
        name: json['name'] as String,
        status: switch (json['status']) {
          final String name => AttendanceStatus.values.byName(name),
          _ => null,
        },
      );
}
