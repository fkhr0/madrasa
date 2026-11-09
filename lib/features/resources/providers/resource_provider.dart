import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';

import '../models/resource_model.dart';
import '../repo/api_resource_repository.dart';
import '../repo/mock_resource_repository.dart';
import '../repo/resource_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => AppConfig.useApi
      ? ApiResourceRepository(watchApi(ref))
      : MockResourceRepository(),
);

/// Material for the signed-in student, or the parent's selected child.
/// A teacher sees what they share in their classes; the office, all.
final resourcesProvider = FutureProvider<List<ResourceModel>>((ref) {
  final repository = ref.watch(resourceRepositoryProvider);
  final role = ref.watch(currentUserProvider).role;
  if (role == UserRole.teacher || role == UserRole.admin) {
    return repository.getTeaching();
  }
  return repository.getAll(ref.watch(activeStudentIdProvider));
});

/// A class's material for the subject's teacher or the office.
final classResourcesProvider =
    FutureProvider.family<List<ResourceModel>, String>(
      (ref, classId) =>
          ref.watch(resourceRepositoryProvider).getClassResources(classId),
    );

/// Selected subject chip; null means "All".
final resourceSubjectProvider = StateProvider<String?>((ref) => null);

final resourceSearchProvider = StateProvider<String>((ref) => '');

final filteredResourcesProvider = FutureProvider<List<ResourceModel>>((
  ref,
) async {
  final subjectId = ref.watch(resourceSubjectProvider);
  final query = ref.watch(resourceSearchProvider).trim().toLowerCase();
  final all = await ref.watch(resourcesProvider.future);

  return all
      .where((r) => subjectId == null || r.subject.id == subjectId)
      .where((r) => query.isEmpty || r.title.toLowerCase().contains(query))
      .toList();
});

final resourceActionsProvider = Provider<ResourceActions>(ResourceActions.new);

/// Sharing and removing material. They throw ApiException with a message.
class ResourceActions {
  final Ref _ref;

  ResourceActions(this._ref);

  Future<void> add({
    required String classId,
    required String subjectId,
    required String title,
    required ResourceType type,
    String? fileId,
    String? url,
  }) async {
    await _ref
        .read(resourceRepositoryProvider)
        .addResource(
          classId: classId,
          subjectId: subjectId,
          title: title,
          type: type,
          fileId: fileId,
          url: url,
        );
    _ref
      ..invalidate(classResourcesProvider(classId))
      ..invalidate(resourcesProvider);
  }

  Future<void> delete(ResourceModel resource, String classId) async {
    await _ref.read(resourceRepositoryProvider).deleteResource(resource.id);
    _ref
      ..invalidate(classResourcesProvider(classId))
      ..invalidate(resourcesProvider);
  }
}
