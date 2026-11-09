/// Numbers for the administrator's home page.
class SchoolStatsModel {
  final int students;
  final int teachers;
  final int parents;
  final int classes;

  /// Students marked present or late today.
  final int presentToday;
  final int absentToday;

  /// Classes whose teacher has not taken attendance for the current period.
  final List<String> classesMissingAttendance;

  const SchoolStatsModel({
    required this.students,
    required this.teachers,
    required this.parents,
    required this.classes,
    required this.presentToday,
    required this.absentToday,
    required this.classesMissingAttendance,
  });

  factory SchoolStatsModel.fromJson(Map<String, dynamic> json) =>
      SchoolStatsModel(
        students: json['students'] as int,
        teachers: json['teachers'] as int,
        parents: json['parents'] as int,
        classes: json['classes'] as int,
        presentToday: json['presentToday'] as int,
        absentToday: json['absentToday'] as int,
        classesMissingAttendance: [
          for (final c in json['classesMissingAttendance'] as List) c as String,
        ],
      );

  double get attendanceRateToday {
    final total = presentToday + absentToday;
    return total == 0 ? 100 : presentToday / total * 100;
  }
}
