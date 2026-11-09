import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/assignments/models/assignment_model.dart';
import 'package:school/features/assignments/models/attachment_model.dart';
import 'package:school/features/assignments/repo/mock_assignment_repository.dart';

Map<String, dynamic> _json({Map<String, dynamic>? submission}) => {
  'id': 'w1',
  'classId': 'cls-5a',
  'className': '5th Scientific – A',
  'type': 'homework',
  'title': 'Worksheet 5',
  'description': 'Questions 1–5',
  'assignedAt': '2026-11-01T06:00:00.000Z',
  'dueAt': '2026-11-03T20:59:00.000Z',
  'allowsLate': false,
  'acceptsFiles': true,
  'maxGrade': 10,
  'subjectId': 'math',
  'subjectName': 'Mathematics',
  'icon': 'math',
  'color': 'purple',
  'teacherName': 'Ahmed Kareem',
  'attachments': [
    {
      'id': 'f1',
      'name': 'Worksheet 5.pdf',
      'mime': 'application/pdf',
      'size': 491520,
    },
  ],
  'submission': submission,
};

void main() {
  test('status comes from the hand-in and the grade', () {
    expect(AssignmentModel.fromJson(_json()).status, AssignmentStatus.pending);

    final handedIn = AssignmentModel.fromJson(
      _json(
        submission: {
          'submittedAt': '2026-11-02T17:00:00.000Z',
          'grade': null,
          'feedback': null,
          'files': [
            {'id': 'f2', 'name': 'answers.jpg', 'size': 2048},
          ],
        },
      ),
    );
    expect(handedIn.status, AssignmentStatus.submitted);
    expect(handedIn.submittedFiles.single.type, AttachmentType.image);

    final graded = AssignmentModel.fromJson(
      _json(
        submission: {
          'submittedAt': '2026-11-02T17:00:00.000Z',
          'grade': 9,
          'feedback': 'Well done',
          'files': [],
        },
      ),
    );
    expect(graded.status, AssignmentStatus.graded);
    expect(graded.grade, 9);
    expect(graded.feedback, 'Well done');
    expect(graded.attachments.single.size, '480 KB');
  });

  test('a draft goes to the server in UTC with the file IDs', () {
    final json = AssignmentDraftModel(
      classId: 'cls-5a',
      subjectId: 'math',
      title: 'Worksheet 5',
      type: AssignmentType.project,
      description: '',
      dueDate: DateTime.utc(2026, 11, 10, 20, 59),
      allowsLateSubmission: true,
      acceptsFiles: false,
      maxGrade: 20,
      attachments: const [
        AttachmentModel(
          id: 'f1',
          name: 'a.pdf',
          type: AttachmentType.pdf,
          size: '1 KB',
        ),
      ],
    ).toJson();

    expect(json['dueAt'], '2026-11-10T20:59:00.000Z');
    expect(json['type'], 'project');
    expect(json['fileIds'], ['f1']);
  });

  test('mock: set work, grade a student, delete', () async {
    final repo = MockAssignmentRepository();
    await repo.saveAssignment(
      AssignmentDraftModel(
        classId: 'cls-5b',
        subjectId: 'math',
        title: 'Practice set',
        type: AssignmentType.homework,
        description: 'All of page 40',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        allowsLateSubmission: false,
        acceptsFiles: false,
      ),
    );
    final work = (await repo.getClassAssignments(
      'cls-5b',
    )).firstWhere((a) => a.title == 'Practice set');
    expect(work.className, '5th Scientific – B');

    final (_, students) = await repo.getSubmissions(work.id);
    await repo.grade(work.id, students.first.id, grade: 8, feedback: 'Good');

    final (updated, after) = await repo.getSubmissions(work.id);
    expect(updated.gradedCount, 1);
    expect(after.first.grade, 8);

    await repo.deleteAssignment(work.id);
    expect(
      (await repo.getClassAssignments('cls-5b')).any((a) => a.id == work.id),
      isFalse,
    );
  });
}
