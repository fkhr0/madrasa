import '../models/insights_model.dart';

/// Fake school statistics until reports come from the server
/// (the server works them out from attendance, grades and trips).
class MockInsights {
  MockInsights._();

  static InsightsModel forPeriod(InsightsPeriod period) {
    switch (period) {
      case InsightsPeriod.week:
        return const InsightsModel(
          period: InsightsPeriod.week,
          attendanceRate: 0.93,
          attendanceChange: 1.2,
          attendanceByDay: [
            LabeledValue('Sun', 0.95),
            LabeledValue('Mon', 0.94),
            LabeledValue('Tue', 0.93),
            LabeledValue('Wed', 0.92),
            LabeledValue('Thu', 0.88),
          ],
          attendanceByClass: [
            LabeledValue('4th Scientific – A', 0.96),
            LabeledValue('5th Scientific – A', 0.94),
            LabeledValue('5th Scientific – B', 0.90),
            LabeledValue('6th Scientific – C', 0.86),
          ],
          averageGrade: 72.4,
          passRate: 0.89,
          gradeBySubject: _grades,
          assignmentsGiven: 18,
          submissionRate: 0.84,
          tripsDone: 20,
          onTimeRate: 0.9,
          averageDelayMinutes: 4,
        );
      case InsightsPeriod.month:
        return const InsightsModel(
          period: InsightsPeriod.month,
          attendanceRate: 0.91,
          attendanceChange: -0.8,
          attendanceByDay: [
            LabeledValue('Sun', 0.94),
            LabeledValue('Mon', 0.92),
            LabeledValue('Tue', 0.91),
            LabeledValue('Wed', 0.90),
            LabeledValue('Thu', 0.86),
          ],
          attendanceByClass: [
            LabeledValue('4th Scientific – A', 0.95),
            LabeledValue('5th Scientific – A', 0.92),
            LabeledValue('5th Scientific – B', 0.89),
            LabeledValue('6th Scientific – C', 0.84),
          ],
          averageGrade: 70.8,
          passRate: 0.86,
          gradeBySubject: _grades,
          assignmentsGiven: 64,
          submissionRate: 0.81,
          tripsDone: 84,
          onTimeRate: 0.87,
          averageDelayMinutes: 6,
        );
      case InsightsPeriod.term:
        return const InsightsModel(
          period: InsightsPeriod.term,
          attendanceRate: 0.92,
          attendanceChange: 0.5,
          attendanceByDay: [
            LabeledValue('Sun', 0.94),
            LabeledValue('Mon', 0.93),
            LabeledValue('Tue', 0.92),
            LabeledValue('Wed', 0.91),
            LabeledValue('Thu', 0.87),
          ],
          attendanceByClass: [
            LabeledValue('4th Scientific – A', 0.95),
            LabeledValue('5th Scientific – A', 0.93),
            LabeledValue('5th Scientific – B', 0.90),
            LabeledValue('6th Scientific – C', 0.85),
          ],
          averageGrade: 71.3,
          passRate: 0.87,
          gradeBySubject: _grades,
          assignmentsGiven: 112,
          submissionRate: 0.83,
          tripsDone: 128,
          onTimeRate: 0.88,
          averageDelayMinutes: 5,
        );
    }
  }

  static const _grades = [
    LabeledValue('Islamic Education', 84),
    LabeledValue('Arabic', 76),
    LabeledValue('English', 74),
    LabeledValue('Biology', 71),
    LabeledValue('Chemistry', 66),
    LabeledValue('Mathematics', 63),
    LabeledValue('Physics', 58),
  ];
}
