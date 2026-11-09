import '../../../core/network/api_client.dart';
import '../models/resource_model.dart';
import 'resource_repository.dart';

/// Study material on the school API (server/src/features/resources).
class ApiResourceRepository implements ResourceRepository {
  final ApiClient _api;

  const ApiResourceRepository(this._api);

  @override
  Future<List<ResourceModel>> getAll(String studentId) =>
      _list('/resources/students/$studentId');

  @override
  Future<List<ResourceModel>> getTeaching() => _list('/resources/teaching');

  @override
  Future<List<ResourceModel>> getClassResources(String classId) =>
      _list('/resources/classes/$classId');

  @override
  Future<void> addResource({
    required String classId,
    required String subjectId,
    required String title,
    required ResourceType type,
    String? fileId,
    String? url,
  }) => _api.post('/resources/classes/$classId', {
    'subjectId': subjectId,
    'title': title,
    'type': type.name,
    'fileId': fileId,
    'url': url,
  });

  @override
  Future<void> deleteResource(String resourceId) =>
      _api.delete('/resources/$resourceId');

  Future<List<ResourceModel>> _list(String path) async => [
    for (final json in await _api.get(path) as List)
      ResourceModel.fromJson(json as Map<String, dynamic>),
  ];
}
