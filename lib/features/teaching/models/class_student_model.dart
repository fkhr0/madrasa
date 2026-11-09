/// A student as the teacher sees them inside one class.
class ClassStudentModel {
  final String id;
  final String name;

  /// The student's average in this teacher's subject (0–100), or null
  /// while there are no grades.
  final double? average;

  /// Attendance rate in this subject (0–100), or null before any marks.
  final double? attendanceRate;

  const ClassStudentModel({
    required this.id,
    required this.name,
    this.average,
    this.attendanceRate,
  });

  factory ClassStudentModel.fromJson(Map<String, dynamic> json) =>
      ClassStudentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        average: (json['average'] as num?)?.toDouble(),
        attendanceRate: (json['attendanceRate'] as num?)?.toDouble(),
      );
}
