import '../../../core/utils/grade_scale.dart';
import '../../exams/models/exam_model.dart';
import '../../institution/models/term_model.dart';
import '../../subjects/models/subject_model.dart';

/// A subject's year result, the Iraqi way (all marks out of 100): 1st term work
/// = average of the monthly exams of the first semester 2nd term work = average
/// of the monthly exams of the second semester year work (السعي السنوي) = (1st
/// term + mid-year exam + 2nd term) ÷ 3 result = (year work + final exam) ÷ 2 →
/// pass from 50 Quizzes show in Grades but don't count here.
class YearResultModel {
  final SubjectModel subject;
  final double? firstTerm;
  final double? midYear;
  final double? secondTerm;
  final double? finalExam;

  const YearResultModel({
    required this.subject,
    this.firstTerm,
    this.midYear,
    this.secondTerm,
    this.finalExam,
  });

  /// السعي السنوي, once its three parts are known.
  double? get yearWork {
    final (a, b, c) = (firstTerm, midYear, secondTerm);
    if (a == null || b == null || c == null) return null;
    return (a + b + c) / 3;
  }

  /// The average of the year-work parts known so far, for an early idea.
  double? get yearWorkSoFar {
    final known = [?firstTerm, ?midYear, ?secondTerm];
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a + b) / known.length;
  }

  /// The final mark for the year, once the final exam is marked.
  double? get result {
    final (work, last) = (yearWork, finalExam);
    if (work == null || last == null) return null;
    return (work + last) / 2;
  }

  bool? get passed => result == null ? null : result! >= GradeScale.passMark;
}

/// One result per subject that has at least one counted mark, by name.
/// [terms] are the study year's semesters (the first two count).
List<YearResultModel> yearResults(
  List<ExamModel> exams,
  List<TermModel> terms,
) {
  final semesters = [...terms]..sort((a, b) => a.start.compareTo(b.start));
  final first = semesters.firstOrNull;
  final second = semesters.length > 1 ? semesters[1] : null;

  final scored = exams.where((e) => e.hasResult && e.type != ExamType.quiz);
  final bySubject = <String, List<ExamModel>>{};
  for (final e in scored) {
    bySubject.putIfAbsent(e.subject.id, () => []).add(e);
  }

  double? average(Iterable<ExamModel> list) {
    if (list.isEmpty) return null;
    return list.map((e) => e.percentage).reduce((a, b) => a + b) / list.length;
  }

  /// The latest exam of [type] (a retake replaces the first try).
  double? latest(List<ExamModel> list, ExamType type) {
    final of = list.where((e) => e.type == type).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return of.lastOrNull?.percentage;
  }

  final results = [
    for (final list in bySubject.values)
      YearResultModel(
        subject: list.first.subject,
        firstTerm: first == null
            ? null
            : average(
                list.where(
                  (e) => e.type == ExamType.monthly && first.includes(e.start),
                ),
              ),
        midYear: latest(list, ExamType.midYear),
        secondTerm: second == null
            ? null
            : average(
                list.where(
                  (e) => e.type == ExamType.monthly && second.includes(e.start),
                ),
              ),
        finalExam: latest(list, ExamType.finalExam),
      ),
  ];
  return results..sort((a, b) => a.subject.name.compareTo(b.subject.name));
}
