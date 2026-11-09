import '../../../core/network/api_client.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';
import 'assignment_repository.dart';

/// Homework on the school API (server/src/features/assignments).
class ApiAssignmentRepository implements AssignmentRepository {
  final ApiClient _api;

  const ApiAssignmentRepository(this._api);

  @override
  Future<List<AssignmentModel>> getAll(String studentId) =>
      _list('/assignments/students/$studentId');

  @override
  Future<void> submit(String assignmentId, List<AttachmentModel> files) =>
      _api.post('/assignments/$assignmentId/submission', {
        'fileIds': [for (final f in files) f.id],
      });

  @override
  Future<List<AssignmentModel>> getClassAssignments(String classId) =>
      _list('/assignments/classes/$classId');

  @override
  Future<void> saveAssignment(
    AssignmentDraftModel draft, {
    String? assignmentId,
  }) => assignmentId == null
      ? _api.post('/assignments/classes/${draft.classId}', draft.toJson())
      : _api.patch('/assignments/$assignmentId', draft.toJson());

  @override
  Future<void> deleteAssignment(String assignmentId) =>
      _api.delete('/assignments/$assignmentId');

  @override
  Future<(AssignmentModel, List<StudentSubmissionModel>)> getSubmissions(
    String assignmentId,
  ) async {
    final json =
        await _api.get('/assignments/$assignmentId/submissions') as Map;
    return (
      AssignmentModel.fromJson(json['assignment'] as Map<String, dynamic>),
      [
        for (final s in json['students'] as List)
          StudentSubmissionModel.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<void> grade(
    String assignmentId,
    String studentId, {
    required double grade,
    required String feedback,
  }) => _api.put('/assignments/$assignmentId/submissions/$studentId/grade', {
    'grade': grade,
    'feedback': feedback,
  });

  Future<List<AssignmentModel>> _list(String path) async => [
    for (final json in await _api.get(path) as List)
      AssignmentModel.fromJson(json as Map<String, dynamic>),
  ];
}
