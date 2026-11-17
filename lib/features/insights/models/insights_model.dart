import '../../../core/l10n/language.dart';

enum InsightsPeriod {
  week,
  month,
  term;

  String get label {
    switch (this) {
      case InsightsPeriod.week:
        return tr('This week');
      case InsightsPeriod.month:
        return tr('This month');
      case InsightsPeriod.term:
        return tr('This term');
    }
  }
}

class LabeledValue {
  final String label;
  final double value;

  const LabeledValue(this.label, this.value);

  factory LabeledValue.fromJson(Map<String, dynamic> json) => LabeledValue(
    json['label'] as String,
    (json['value'] as num? ?? 0).toDouble(),
  );
}

class InsightsModel {
  final InsightsPeriod period;

  final double attendanceRate;

  final double attendanceChange;
  final List<LabeledValue> attendanceByDay;
  final List<LabeledValue> attendanceByClass;

  final double averageGrade;
  final double passRate;
  final List<LabeledValue> gradeBySubject;

  final int assignmentsGiven;
  final double submissionRate;

  final int tripsDone;
  final double onTimeRate;
  final int averageDelayMinutes;

  bool get hasAttendance =>
      attendanceByClass.isNotEmpty || attendanceByDay.isNotEmpty;
  bool get hasGrades => gradeBySubject.isNotEmpty;
  bool get hasHomework => assignmentsGiven > 0;
  bool get hasTrips => tripsDone > 0;
  bool get isEmpty => !hasAttendance && !hasGrades && !hasHomework && !hasTrips;

  const InsightsModel({
    required this.period,
    required this.attendanceRate,
    required this.attendanceChange,
    required this.attendanceByDay,
    required this.attendanceByClass,
    required this.averageGrade,
    required this.passRate,
    required this.gradeBySubject,
    required this.assignmentsGiven,
    required this.submissionRate,
    required this.tripsDone,
    required this.onTimeRate,
    required this.averageDelayMinutes,
  });

  factory InsightsModel.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    List<LabeledValue> list(String key) => [
      for (final v in json[key] as List? ?? const [])
        LabeledValue.fromJson(v as Map<String, dynamic>),
    ];

    return InsightsModel(
      period: InsightsPeriod.values.byName(json['period'] as String),
      attendanceRate: number('attendanceRate'),
      attendanceChange: number('attendanceChange'),
      attendanceByDay: list('attendanceByDay'),
      attendanceByClass: list('attendanceByClass'),
      averageGrade: number('averageGrade'),
      passRate: number('passRate'),
      gradeBySubject: list('gradeBySubject'),
      assignmentsGiven: json['assignmentsGiven'] as int? ?? 0,
      submissionRate: number('submissionRate'),
      tripsDone: json['tripsDone'] as int? ?? 0,
      onTimeRate: number('onTimeRate'),
      averageDelayMinutes: json['averageDelayMinutes'] as int? ?? 0,
    );
  }
}
