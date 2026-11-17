class ClassSubjectModel {
  final String subjectId;
  final String subjectName;

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

class SchoolClassModel {
  final String id;

  final String name;

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
