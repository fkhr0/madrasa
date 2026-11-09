import '../models/exam_model.dart';

/// MockExamRepository or ApiExamRepository. Failures throw ApiException
/// with a message to show.
abstract class ExamRepository {
  /// Exams of [studentId]'s class, earliest first, with the student's
  /// score once published.
  Future<List<ExamModel>> getCurrentTerm(String studentId);

  // ---------- Teacher of the subject, or administrator ----------

  /// A class's exams (a teacher gets only their subjects), earliest first.
  Future<List<ExamModel>> getClassExams(String classId);

  /// Schedules a new exam, or changes [examId].
  Future<void> saveExam(ExamDraftModel draft, {String? examId});

  /// Its scores go too.
  Future<void> deleteExam(String examId);

  Future<(ExamModel, List<StudentScoreModel>)> getScoreSheet(String examId);

  /// Saves and publishes. A null score removes that student's mark.
  Future<void> saveScores(String examId, Map<String, double?> scores);
}
