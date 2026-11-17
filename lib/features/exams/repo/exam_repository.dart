import '../models/exam_model.dart';

abstract class ExamRepository {
  Future<List<ExamModel>> getCurrentTerm(String studentId);

  Future<List<ExamModel>> getClassExams(String classId);

  Future<void> saveExam(ExamDraftModel draft, {String? examId});

  Future<void> deleteExam(String examId);

  Future<(ExamModel, List<StudentScoreModel>)> getScoreSheet(String examId);

  Future<void> saveScores(String examId, Map<String, double?> scores);
}
