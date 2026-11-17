import '../models/assignment_model.dart';
import '../models/attachment_model.dart';

abstract class AssignmentRepository {
  Future<List<AssignmentModel>> getAll(String studentId);

  Future<void> submit(String assignmentId, List<AttachmentModel> files);

  Future<List<AssignmentModel>> getClassAssignments(String classId);

  Future<void> saveAssignment(
    AssignmentDraftModel draft, {
    String? assignmentId,
  });

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
