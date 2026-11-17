import '../../../core/utils/grade_scale.dart';
import '../models/insights_model.dart';
import '../../../core/l10n/language.dart';

class Highlight {
  final bool isGood;
  final String text;

  const Highlight(this.text, {this.isGood = false});
}

List<Highlight> highlightsFor(InsightsModel data) {
  LabeledValue lowest(List<LabeledValue> list) =>
      list.reduce((a, b) => a.value <= b.value ? a : b);
  LabeledValue highest(List<LabeledValue> list) =>
      list.reduce((a, b) => a.value >= b.value ? a : b);
  String pct(double rate) => '${(rate * 100).round()}%';

  final highlights = <Highlight>[];

  if (!data.hasAttendance) {
  } else if (data.attendanceChange >= 1) {
    highlights.add(
      Highlight(
        tr('Attendance is up {0} points from the previous period.', [
          data.attendanceChange.toStringAsFixed(1),
        ]),
        isGood: true,
      ),
    );
  } else if (data.attendanceChange <= -0.5) {
    highlights.add(
      Highlight(
        tr('Attendance dropped {0} points from the previous period.', [
          (-data.attendanceChange).toStringAsFixed(1),
        ]),
      ),
    );
  }

  final weakClass = data.attendanceByClass.isEmpty
      ? null
      : lowest(data.attendanceByClass);
  if (weakClass != null && data.attendanceRate - weakClass.value >= 0.04) {
    highlights.add(
      Highlight(
        tr(
          '{0} has the lowest attendance ({1}). A word with the homeroom teacher may help.',
          [weakClass.label, pct(weakClass.value)],
        ),
      ),
    );
  }

  final days = data.attendanceByDay;
  final weakDay = days.isEmpty ? null : lowest(days);
  final bestDay = days.isEmpty ? null : highest(days);
  if (weakDay != null &&
      bestDay != null &&
      bestDay.value - weakDay.value >= 0.05) {
    highlights.add(
      Highlight(
        tr('{0} attendance is {1}, {2} points below {3}.', [
          weakDay.label,
          pct(weakDay.value),
          ((bestDay.value - weakDay.value) * 100).round(),
          bestDay.label,
        ]),
      ),
    );
  }

  final weakSubject = data.hasGrades ? lowest(data.gradeBySubject) : null;
  if (weakSubject != null && weakSubject.value < GradeScale.passMark + 15) {
    highlights.add(
      Highlight(
        tr(
          '{0} has the lowest average ({1}/100). Extra support sessions before the exams could help.',
          [weakSubject.label, weakSubject.value.round()],
        ),
      ),
    );
  }

  if (data.hasHomework && data.submissionRate < 0.8) {
    highlights.add(
      Highlight(
        tr('Only {0} of homework was handed in.', [pct(data.submissionRate)]),
      ),
    );
  }

  if (!data.hasTrips) {
  } else if (data.onTimeRate < 0.85) {
    highlights.add(
      Highlight(
        tr('{0} of bus trips were late ({1} min on average).', [
          pct(1 - data.onTimeRate),
          data.averageDelayMinutes,
        ]),
      ),
    );
  } else {
    highlights.add(
      Highlight(
        tr('Buses were on time on {0} of trips.', [pct(data.onTimeRate)]),
        isGood: true,
      ),
    );
  }

  highlights.sort((a, b) => (a.isGood ? 1 : 0) - (b.isGood ? 1 : 0));
  return highlights;
}
