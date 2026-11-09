import '../../../core/l10n/language.dart';

/// The time span the statistics cover.
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

/// A name and a number, e.g. ("Biology", 71.5) or ("Sun", 0.94).
class LabeledValue {
  final String label;
  final double value;

  const LabeledValue(this.label, this.value);

  factory LabeledValue.fromJson(Map<String, dynamic> json) => LabeledValue(
    json['label'] as String,
    (json['value'] as num? ?? 0).toDouble(),
  );
}

/// The school in numbers for one period (doc: admin reports).
class InsightsModel {
  final InsightsPeriod period;

  // Attendance, rates are 0–1.
  final double attendanceRate;

  /// Change from the previous period, in percentage points (+1.5, -2).
  final double attendanceChange;
  final List<LabeledValue> attendanceByDay;
  final List<LabeledValue> attendanceByClass;

  // Learning, grades out of 100, pass = 50.
  final double averageGrade;
  final double passRate;
  final List<LabeledValue> gradeBySubject;

  // Homework
  final int assignmentsGiven;
  final double submissionRate;

  // Transport
  final int tripsDone;
  final double onTimeRate;
  final int averageDelayMinutes;

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
