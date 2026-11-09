import '../../../core/utils/day_json.dart';

/// The school's fees: tuition, bus fee, installment dates, and classes
/// whose tuition differs.
class FinanceSettingsModel {
  final int tuition;
  final int busFee;
  final List<DateTime> dueDates;

  /// Every class; tuition null = the school's tuition.
  final List<ClassTuitionModel> classTuition;

  const FinanceSettingsModel({
    required this.tuition,
    required this.busFee,
    required this.dueDates,
    required this.classTuition,
  });

  factory FinanceSettingsModel.fromJson(Map<String, dynamic> json) =>
      FinanceSettingsModel(
        tuition: json['tuition'] as int,
        busFee: json['busFee'] as int,
        dueDates: [
          for (final d in json['dueDates'] as List) parseDay(d as String),
        ],
        classTuition: [
          for (final c in json['classTuition'] as List)
            ClassTuitionModel(
              classId: c['classId'] as String,
              className: c['className'] as String,
              tuition: c['tuition'] as int?,
            ),
        ],
      );

  Map<String, dynamic> toJson() => {
    'tuition': tuition,
    'busFee': busFee,
    'dueDates': [for (final d in dueDates) formatDay(d)],
    'classTuition': {for (final c in classTuition) c.classId: c.tuition},
  };
}

class ClassTuitionModel {
  final String classId;
  final String className;

  /// Null = the school's tuition.
  final int? tuition;

  const ClassTuitionModel({
    required this.classId,
    required this.className,
    this.tuition,
  });
}
