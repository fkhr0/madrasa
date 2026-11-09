import '../models/resource_model.dart';

/// Study material teachers share with a class. MockResourceRepository or
/// ApiResourceRepository. Failures throw ApiException with a message.
abstract class ResourceRepository {
  /// Material for [studentId]'s class, newest first.
  Future<List<ResourceModel>> getAll(String studentId);

  // ---------- Teacher of the subject, or administrator ----------

  /// A teacher: what they share in all their classes. The office: all.
  Future<List<ResourceModel>> getTeaching();

  Future<List<ResourceModel>> getClassResources(String classId);

  /// Shares a file (already uploaded, [fileId]) or a link ([url]).
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
