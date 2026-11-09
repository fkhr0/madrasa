import '../../subjects/data/mock_subjects.dart';
import '../data/mock_resources.dart';
import '../models/resource_model.dart';
import 'resource_repository.dart';

/// Mock material (lost on reload). Students see MockResources; staff get a
/// list per class that starts with the maths material.
class MockResourceRepository implements ResourceRepository {
  final _byClass = <String, List<ResourceModel>>{};
  int _nextId = 1;

  @override
  Future<List<ResourceModel>> getAll(String studentId) async =>
      MockResources.items..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

  @override
  Future<List<ResourceModel>> getTeaching() async => getAll('');

  @override
  Future<List<ResourceModel>> getClassResources(String classId) async =>
      [..._class(classId)]
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

  List<ResourceModel> _class(String classId) => _byClass.putIfAbsent(
    classId,
    () => [
      for (final r in MockResources.items)
        if (r.subject.id == MockSubjects.math.id) r,
    ],
  );

  @override
  Future<void> addResource({
    required String classId,
    required String subjectId,
    required String title,
    required ResourceType type,
    String? fileId,
    String? url,
  }) async => _class(classId).add(
    ResourceModel(
      id: 'mock-resource-${_nextId++}',
      title: title,
      subject: MockSubjects.all.firstWhere((s) => s.id == subjectId),
      type: type,
      uploadedAt: DateTime.now(),
      url: url,
      classId: classId,
    ),
  );

  @override
  Future<void> deleteResource(String resourceId) async {
    for (final list in _byClass.values) {
      list.removeWhere((r) => r.id == resourceId);
    }
  }
}
