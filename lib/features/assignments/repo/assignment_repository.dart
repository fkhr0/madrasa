import '../models/assignment_model.dart';
import '../models/attachment_model.dart';

/// MockAssignmentRepository or ApiAssignmentRepository. Failures throw
/// ApiException with a message to show.
abstract class AssignmentRepository {
  /// All assignments of [studentId]'s class, nearest due date first, with
  /// the student's hand-in and grade.
  Future<List<AssignmentModel>> getAll(String studentId);

  /// Hands in [files] (already uploaded), or marks work without files as done.
  Future<void> submit(String assignmentId, List<AttachmentModel> files);

  // ---------- Teacher of the subject, or administrator ----------

  /// A class's work (a teacher gets only their subjects), latest due first.
  Future<List<AssignmentModel>> getClassAssignments(String classId);

  /// Sets new work, or changes [assignmentId].
  Future<void> saveAssignment(
    AssignmentDraftModel draft, {
    String? assignmentId,
  });

  /// Its hand-ins and grades go too.
  Future<void> deleteAssignment(String assignmentId);

  Future<(AssignmentModel, List<StudentSubmissionModel>)> getSubmissions(
    String assignmentId,
  );

  Future<void> grade(
    String assignmentId,
    String studentId, {
    required double grade,
    required String feedback,
  });
}
