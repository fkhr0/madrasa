import '../../subjects/data/mock_subjects.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';

/// Fake assignments. Dates are relative to today so the app always
/// has something due soon, something late and something graded.
class MockAssignments {
  MockAssignments._();

  static DateTime _day(int offset, [int hour = 23, int minute = 59]) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, hour, minute);
  }

  static List<AssignmentModel> get items => [
    AssignmentModel(
      id: 'a1',
      title: 'Quadratic equations – worksheet 4',
      subject: MockSubjects.math,
      type: AssignmentType.homework,
      description:
          'Solve questions 1 to 12 on the worksheet. Show every step of '
          'your work; final answers alone will not get full marks.',
      assignedAt: _day(-3, 9),
      dueDate: _day(1),
      status: AssignmentStatus.pending,
      attachments: const [
        AttachmentModel(
          name: 'Worksheet 4.pdf',
          type: AttachmentType.pdf,
          size: '480 KB',
        ),
      ],
    ),
    AssignmentModel(
      id: 'a2',
      title: 'Lab report: rates of reaction',
      subject: MockSubjects.chemistry,
      type: AssignmentType.assignment,
      description:
          'Write up the experiment from Monday\'s lab. Include your '
          'hypothesis, method, results table, a graph and a short conclusion.',
      assignedAt: _day(-5, 10),
      dueDate: _day(3),
      status: AssignmentStatus.pending,
      allowsLateSubmission: true,
      attachments: const [
        AttachmentModel(
          name: 'Report template.docx',
          type: AttachmentType.document,
          size: '64 KB',
        ),
        AttachmentModel(
          name: 'Lab results.png',
          type: AttachmentType.image,
          size: '1.2 MB',
        ),
      ],
    ),
    AssignmentModel(
      id: 'a3',
      title: 'Essay: a place I remember',
      subject: MockSubjects.english,
      type: AssignmentType.assignment,
      description:
          'A descriptive essay of 400–500 words about a place that matters '
          'to you. Focus on the senses.',
      assignedAt: _day(-8, 11),
      dueDate: _day(-1),
      status: AssignmentStatus.pending,
      allowsLateSubmission: true,
    ),
    AssignmentModel(
      id: 'a4',
      title: 'Newton\'s laws quiz',
      subject: MockSubjects.physics,
      type: AssignmentType.quiz,
      description: 'Short quiz in class covering chapter 3.',
      assignedAt: _day(-2, 8),
      dueDate: _day(5, 9, 40),
      status: AssignmentStatus.pending,
    ),
    AssignmentModel(
      id: 'a5',
      title: 'Build a simple calculator',
      subject: MockSubjects.computer,
      type: AssignmentType.project,
      description:
          'Use what we covered about functions and conditions to build a '
          'calculator that supports + − × ÷. Submit your source file.',
      assignedAt: _day(-10, 12),
      dueDate: _day(-2),
      status: AssignmentStatus.submitted,
      submittedAt: _day(-3, 20, 15),
      submittedFiles: const [
        AttachmentModel(
          name: 'calculator.py',
          type: AttachmentType.other,
          size: '3 KB',
        ),
      ],
    ),
    AssignmentModel(
      id: 'a6',
      title: 'Surat Al-Hujurat – lesson summary',
      subject: MockSubjects.islamic,
      type: AssignmentType.homework,
      description: 'One page summary of the lessons from Surat Al-Hujurat.',
      assignedAt: _day(-14, 9),
      dueDate: _day(-7),
      status: AssignmentStatus.graded,
      submittedAt: _day(-8, 18),
      submittedFiles: const [
        AttachmentModel(
          name: 'hujurat_summary.pdf',
          type: AttachmentType.pdf,
          size: '220 KB',
        ),
      ],
      grade: 18,
      maxGrade: 20,
      feedback:
          'Clear and well organised. Next time support each lesson with '
          'a verse number.',
    ),
    AssignmentModel(
      id: 'a7',
      title: 'Poetry analysis',
      subject: MockSubjects.arabic,
      type: AssignmentType.assignment,
      description: 'Analyse the poem from page 42 in your own words.',
      assignedAt: _day(-12, 9),
      dueDate: _day(-5),
      status: AssignmentStatus.graded,
      submittedAt: _day(-6, 21),
      grade: 41,
      maxGrade: 50,
      feedback: 'Good understanding of the imagery. Watch your spelling.',
    ),
  ];
}
