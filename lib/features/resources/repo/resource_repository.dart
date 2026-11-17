import '../models/resource_model.dart';

abstract class ResourceRepository {
  Future<List<ResourceModel>> getAll(String studentId);

  Future<List<ResourceModel>> getTeaching();

  Future<List<ResourceModel>> getClassResources(String classId);

  Future<void> addResource({
    required String classId,
    required String subjectId,
    required String title,
    required ResourceType type,
    String? fileId,
    String? url,
  });

  Future<void> deleteResource(String resourceId);
}
