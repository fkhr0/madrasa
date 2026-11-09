import '../../academics/models/subject_style.dart';
import '../../subjects/models/subject_model.dart';

/// A class a teacher teaches, e.g. "5th Scientific – A" for Mathematics.
class TeachingClassModel {
  final String id;
  final String name;
  final SubjectModel subject;
  final String room;
  final int studentCount;

  /// Past exams (and, later, handed-in work) still waiting for scores.
  final int toGradeCount;

  const TeachingClassModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.room,
    required this.studentCount,
    this.toGradeCount = 0,
  });

  factory TeachingClassModel.fromJson(
    Map<String, dynamic> json, {
    required String teacherName,
  }) {
    final subject = json['subject'] as Map<String, dynamic>;

    return TeachingClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      subject: SubjectModel(
        id: subject['id'] as String,
        name: subject['name'] as String,
        teacherName: teacherName,
        icon: SubjectStyle.icon(subject['icon'] as String? ?? 'book'),
        color: SubjectStyle.color(subject['color'] as String? ?? 'blue'),
      ),
      room: json['room'] as String? ?? '',
      studentCount: json['studentCount'] as int? ?? 0,
      toGradeCount: json['toGradeCount'] as int? ?? 0,
    );
  }
}
