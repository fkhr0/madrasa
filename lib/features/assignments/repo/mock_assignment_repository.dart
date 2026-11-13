import '../../academics/data/mock_school_classes.dart';
import '../../subjects/data/mock_subjects.dart';
import '../../teaching/data/mock_teaching.dart';
import '../data/mock_assignments.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';
import 'assignment_repository.dart';

/// Keeps assignments in memory so submitting and grading work during the session.
class MockAssignmentRepository implements AssignmentRepository {
  final List<AssignmentModel> _items = MockAssignments.items;
  final _byClass = <String, List<AssignmentModel>>{};

  /// "assignmentId/studentId" → hand-in.
  final _submissions = <String, StudentSubmissionModel>{};
  int _nextId = 1;

  @override
  Future<List<AssignmentModel>> getAll(String studentId) async {
    return [..._items]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<void> submit(String assignmentId, List<AttachmentModel> files) async {
    final index = _items.indexWhere((a) => a.id == assignmentId);
    if (index == -1) return;

    _items[index] = _items[index].copyWith(
      status: AssignmentStatus.submitted,
      submittedFiles: files,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<List<AssignmentModel>> getClassAssignments(String classId) async =>
      [for (final a in _class(classId)) _withCounts(a)]
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  List<AssignmentModel> _class(String classId) => _byClass.putIfAbsent(
    classId,
    () => [
      for (final a in _items)
        if (a.subject.id == MockSubjects.math.id)
          _copy(a, id: '${a.id}-$classId', classId: classId),
    ],
  );

  @override
  Future<void> saveAssignment(
    AssignmentDraftModel draft, {
    String? assignmentId,
  }) async {
    final list = _class(draft.classId);
    final old = list.where((a) => a.id == assignmentId).firstOrNull;
    final assignment = AssignmentModel(
      id: assignmentId ?? 'mock-work-${_nextId++}',
      title: draft.title,
      subject: MockSubjects.all.firstWhere((s) => s.id == draft.subjectId),
      type: draft.type,
      description: draft.description,
      assignedAt: old?.assignedAt ?? DateTime.now(),
      dueDate: draft.dueDate,
      status: AssignmentStatus.pending,
      attachments: draft.attachments,
      allowsLateSubmission: draft.allowsLateSubmission,
      acceptsFiles: draft.acceptsFiles,
      maxGrade: draft.maxGrade,
      classId: draft.classId,
      className: _className(draft.classId),
    );
    list
      ..removeWhere((a) => a.id == assignmentId)
      ..add(assignment);
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    for (final list in _byClass.values) {
      list.removeWhere((a) => a.id == assignmentId);
    }
    _submissions.removeWhere((key, _) => key.startsWith('$assignmentId/'));
  }

  @override
  Future<(AssignmentModel, List<StudentSubmissionModel>)> getSubmissions(
    String assignmentId,
  ) async {
    final assignment = _find(assignmentId);
    return (
      _withCounts(assignment),
      [
        for (final s in MockTeaching.studentsOf(assignment.classId))
          _submissions['$assignmentId/${s.id}'] ??
              StudentSubmissionModel(id: s.id, name: s.name),
      ],
    );
  }

  @override
  Future<void> grade(
    String assignmentId,
    String studentId, {
    required double grade,
    required String feedback,
  }) async {
    final key = '$assignmentId/$studentId';
    final student = MockTeaching.studentsOf(
      _find(assignmentId).classId,
    ).firstWhere((s) => s.id == studentId);
    final old = _submissions[key];
    _submissions[key] = StudentSubmissionModel(
      id: studentId,
      name: student.name,
      submittedAt: old?.submittedAt,
      files: old?.files ?? const [],
      grade: grade,
      feedback: feedback.isEmpty ? null : feedback,
    );
  }

  AssignmentModel _find(String id) =>
      _byClass.values.expand((l) => l).firstWhere((a) => a.id == id);

  AssignmentModel _withCounts(AssignmentModel a) {
    final subs = _submissions.entries
        .where((e) => e.key.startsWith('${a.id}/'))
        .map((e) => e.value);
    return _copy(
      a,
      submittedCount: subs.where((s) => s.handedIn).length,
      gradedCount: subs.where((s) => s.grade != null).length,
    );
  }

  static String _className(String classId) =>
      MockSchoolClasses.classes.firstWhere((c) => c.id == classId).name;

  static AssignmentModel _copy(
    AssignmentModel a, {
    String? id,
    String? classId,
    int? submittedCount,
    int? gradedCount,
  }) => AssignmentModel(
    id: id ?? a.id,
    title: a.title,
    subject: a.subject,
    type: a.type,
    description: a.description,
    assignedAt: a.assignedAt,
    dueDate: a.dueDate,
    status: AssignmentStatus.pending,
    attachments: a.attachments,
    allowsLateSubmission: a.allowsLateSubmission,
    acceptsFiles: a.acceptsFiles,
    maxGrade: a.maxGrade ?? 10,
    classId: classId ?? a.classId,
    className: classId == null ? a.className : _className(classId),
    submittedCount: submittedCount ?? a.submittedCount,
    gradedCount: gradedCount ?? a.gradedCount,
  );
}
