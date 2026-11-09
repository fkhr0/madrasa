import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/assignment_filter.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';
import '../repo/api_assignment_repository.dart';
import '../repo/assignment_repository.dart';
import '../repo/mock_assignment_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => AppConfig.useApi
      ? ApiAssignmentRepository(watchApi(ref))
      : MockAssignmentRepository(),
);

/// Any student's work.
final studentAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String>((ref, studentId) {
      ref.watch(authProvider.select((user) => user?.id));
      return ref.watch(assignmentRepositoryProvider).getAll(studentId);
    });

/// The signed-in student's work, or the parent's selected child's.
final assignmentsProvider = FutureProvider<List<AssignmentModel>>(
  (ref) => ref.watch(
    studentAssignmentsProvider(ref.watch(activeStudentIdProvider)).future,
  ),
);

final assignmentFilterProvider = StateProvider<AssignmentFilter>(
  (ref) => AssignmentFilter.all,
);

/// Assignments that match the selected filter chip.
final filteredAssignmentsProvider = FutureProvider<List<AssignmentModel>>((
  ref,
) async {
  final filter = ref.watch(assignmentFilterProvider);
  final all = await ref.watch(assignmentsProvider.future);

  return all.where(filter.matches).toList();
});

/// Work still to do, nearest due date first (used on the dashboard).
final pendingAssignmentsProvider = FutureProvider<List<AssignmentModel>>((
  ref,
) async {
  final all = await ref.watch(assignmentsProvider.future);

  return all.where((a) => a.status == AssignmentStatus.pending).toList();
});

/// Taken from the list, so it refreshes together with it (e.g. after submitting).
final assignmentByIdProvider = FutureProvider.family<AssignmentModel?, String>((
  ref,
  id,
) async {
  final all = await ref.watch(assignmentsProvider.future);

  for (final assignment in all) {
    if (assignment.id == id) return assignment;
  }

  return null;
});

/// A class's work for the subject's teacher or the office.
final classAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String>(
      (ref, classId) =>
          ref.watch(assignmentRepositoryProvider).getClassAssignments(classId),
    );

final submissionsProvider =
    FutureProvider.family<
      (AssignmentModel, List<StudentSubmissionModel>),
      String
    >(
      (ref, assignmentId) =>
          ref.watch(assignmentRepositoryProvider).getSubmissions(assignmentId),
    );

final assignmentActionsProvider = Provider<AssignmentActions>(
  AssignmentActions.new,
);

/// Handing in, setting work and grading. Each reloads what it changed.
/// They throw ApiException with a message to show.
class AssignmentActions {
  final Ref _ref;

  AssignmentActions(this._ref);

  AssignmentRepository get _repository =>
      _ref.read(assignmentRepositoryProvider);

  Future<void> submit(String assignmentId, List<AttachmentModel> files) async {
    await _repository.submit(assignmentId, files);
    _ref.invalidate(studentAssignmentsProvider);
  }

  Future<void> saveAssignment(
    AssignmentDraftModel draft, {
    String? assignmentId,
  }) async {
    await _repository.saveAssignment(draft, assignmentId: assignmentId);
    _reloadClass(draft.classId);
    if (assignmentId != null) {
      _ref.invalidate(submissionsProvider(assignmentId));
    }
  }

  Future<void> deleteAssignment(AssignmentModel assignment) async {
    await _repository.deleteAssignment(assignment.id);
    _reloadClass(assignment.classId);
  }

  Future<void> grade(
    AssignmentModel assignment,
    String studentId, {
    required double grade,
    required String feedback,
  }) async {
    await _repository.grade(
      assignment.id,
      studentId,
      grade: grade,
      feedback: feedback,
    );
    _reloadClass(assignment.classId);
    _ref
      ..invalidate(submissionsProvider(assignment.id))
      // "To grade" on the teacher's class cards.
      ..invalidate(myClassesProvider);
  }

  void _reloadClass(String classId) => _ref
    ..invalidate(classAssignmentsProvider(classId))
    ..invalidate(studentAssignmentsProvider);
}
