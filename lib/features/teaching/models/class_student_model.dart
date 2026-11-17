class ClassStudentModel {
  final String id;
  final String name;

  final double? average;

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
