import '../../../core/network/api_client.dart';
import '../models/exam_model.dart';
import 'exam_repository.dart';

/// Exams on the school API (server/src/features/exams).
class ApiExamRepository implements ExamRepository {
  final ApiClient _api;

  const ApiExamRepository(this._api);

  @override
  Future<List<ExamModel>> getCurrentTerm(String studentId) =>
      _list('/exams/students/$studentId');

  @override
  Future<List<ExamModel>> getClassExams(String classId) =>
      _list('/exams/classes/$classId');

  @override
  Future<void> saveExam(ExamDraftModel draft, {String? examId}) =>
      examId == null
      ? _api.post('/exams/classes/${draft.classId}', draft.toJson())
      : _api.patch('/exams/$examId', draft.toJson());

  @override
  Future<void> deleteExam(String examId) => _api.delete('/exams/$examId');

  @override
  Future<(ExamModel, List<StudentScoreModel>)> getScoreSheet(
    String examId,
  ) async {
    final json = await _api.get('/exams/$examId/scores') as Map;

    return (
      ExamModel.fromJson(json['exam'] as Map<String, dynamic>),
      [
        for (final s in json['students'] as List)
          StudentScoreModel.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<void> saveScores(String examId, Map<String, double?> scores) =>
      _api.put('/exams/$examId/scores', {'scores': scores});

  Future<List<ExamModel>> _list(String path) async => [
    for (final json in await _api.get(path) as List)
      ExamModel.fromJson(json as Map<String, dynamic>),
  ];
}
