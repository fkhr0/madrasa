import '../../exams/repo/exam_repository.dart';
import '../models/grade_item_model.dart';
import '../models/subject_grades_model.dart';
import 'grade_repository.dart';

/// Grades are the student's published exam scores, grouped by subject.
class ApiGradeRepository implements GradeRepository {
  final ExamRepository _exams;

  const ApiGradeRepository(this._exams);

  @override
  Future<List<SubjectGradesModel>> getCurrentTerm(String studentId) async {
    final scored = (await _exams.getCurrentTerm(
      studentId,
    )).where((e) => e.hasResult);
    final bySubject = <String, SubjectGradesModel>{};

    for (final exam in scored) {
      final item = GradeItemModel(
        title: exam.displayTitle,
        category: exam.type.label,
        score: exam.score!,
        maxScore: exam.maxScore!,
        date: exam.start,
      );
      final old = bySubject[exam.subject.id];
      bySubject[exam.subject.id] = SubjectGradesModel(
        subject: exam.subject,
        items: [...?old?.items, item],
      );
    }

    return bySubject.values.toList()
      ..sort((a, b) => a.subject.name.compareTo(b.subject.name));
  }
}
