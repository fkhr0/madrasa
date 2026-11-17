import '../../../core/utils/grade_scale.dart';
import '../../exams/models/exam_model.dart';
import '../../institution/models/term_model.dart';
import '../../subjects/models/subject_model.dart';

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

  double? get yearWork {
    final (a, b, c) = (firstTerm, midYear, secondTerm);
    if (a == null || b == null || c == null) return null;
    return (a + b + c) / 3;
  }

  double? get yearWorkSoFar {
    final known = [?firstTerm, ?midYear, ?secondTerm];
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a + b) / known.length;
  }

  double? get result {
    final (work, last) = (yearWork, finalExam);
    if (work == null || last == null) return null;
    return (work + last) / 2;
  }

  bool? get passed => result == null ? null : result! >= GradeScale.passMark;
}

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
