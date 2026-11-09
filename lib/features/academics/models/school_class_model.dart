/// One subject a class studies, and who teaches it there.
class ClassSubjectModel {
  final String subjectId;
  final String subjectName;

  /// Null while no teacher is assigned.
  final String? teacherId;
  final String? teacherName;

  const ClassSubjectModel({
    required this.subjectId,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
  });

  bool get hasTeacher => teacherId != null;

  factory ClassSubjectModel.fromJson(Map<String, dynamic> json) =>
      ClassSubjectModel(
        subjectId: json['subjectId'] as String,
        subjectName: json['subjectName'] as String,
        teacherId: json['teacherId'] as String?,
        teacherName: json['teacherName'] as String?,
      );
}

/// A class as the administrator manages it: e.g. "5th Scientific – A".
class SchoolClassModel {
  /// Empty for a class not saved yet.
  final String id;

  /// Full name, e.g. "5th Scientific – A".
  final String name;

  /// The head of the class (homeroom teacher), if chosen.
  final String? homeroomTeacherId;
  final String? homeroomTeacherName;
  final int studentCount;
  final List<ClassSubjectModel> subjects;

  const SchoolClassModel({
    required this.id,
    required this.name,
    this.homeroomTeacherId,
    this.homeroomTeacherName,
    this.studentCount = 0,
    this.subjects = const [],
  });

  int get unassignedCount => subjects.where((s) => !s.hasTeacher).length;

  factory SchoolClassModel.fromJson(Map<String, dynamic> json) =>
      SchoolClassModel(
        id: json['id'] as String,
        name: json['name'] as String,
        homeroomTeacherId: json['homeroomTeacherId'] as String?,
        homeroomTeacherName: json['homeroomTeacherName'] as String?,
        studentCount: json['studentCount'] as int? ?? 0,
        subjects: [
          for (final s in json['subjects'] as List? ?? const [])
            ClassSubjectModel.fromJson(s as Map<String, dynamic>),
        ],
      );
}
