import '../../auth/data/mock_users.dart';
import '../../subjects/data/mock_subjects.dart';
import '../models/grade_item_model.dart';
import '../models/subject_grades_model.dart';

class MockGrades {
  MockGrades._();

  static DateTime _ago(int days) =>
      DateTime.now().subtract(Duration(days: days));

  static List<SubjectGradesModel> forStudent(String studentId) =>
      studentId == MockUsers.secondStudent.id ? _ali : _zainab;

  /// A younger student with a weaker term, so the parent view has contrast.
  static List<SubjectGradesModel> get _ali => [
    SubjectGradesModel(
      subject: MockSubjects.math,
      items: [
        GradeItemModel(
          title: 'Fractions quiz',
          category: 'Quiz',
          score: 6,
          maxScore: 10,
          date: _ago(15),
        ),
        GradeItemModel(
          title: 'October monthly exam',
          category: 'Monthly exam',
          score: 58,
          maxScore: 100,
          date: _ago(8),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.english,
      items: [
        GradeItemModel(
          title: 'October monthly exam',
          category: 'Monthly exam',
          score: 81,
          maxScore: 100,
          date: _ago(9),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.arabic,
      items: [
        GradeItemModel(
          title: 'October monthly exam',
          category: 'Monthly exam',
          score: 74,
          maxScore: 100,
          date: _ago(10),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.physics,
      items: [
        GradeItemModel(
          title: 'October monthly exam',
          category: 'Monthly exam',
          score: 45,
          maxScore: 100,
          date: _ago(7),
        ),
      ],
    ),
  ];

  static List<SubjectGradesModel> get _zainab => [
    SubjectGradesModel(
      subject: MockSubjects.math,
      items: [
        GradeItemModel(
          title: 'Algebra quiz',
          category: 'Quiz',
          score: 9,
          maxScore: 10,
          date: _ago(20),
        ),
        GradeItemModel(
          title: 'Functions test',
          category: 'Test',
          score: 42,
          maxScore: 50,
          date: _ago(12),
        ),
        GradeItemModel(
          title: 'Worksheet 3',
          category: 'Homework',
          score: 10,
          maxScore: 10,
          date: _ago(5),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.physics,
      items: [
        GradeItemModel(
          title: 'Motion quiz',
          category: 'Quiz',
          score: 7,
          maxScore: 10,
          date: _ago(18),
        ),
        GradeItemModel(
          title: 'Forces lab',
          category: 'Lab',
          score: 16,
          maxScore: 20,
          date: _ago(9),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.chemistry,
      items: [
        GradeItemModel(
          title: 'Periodic table quiz',
          category: 'Quiz',
          score: 8,
          maxScore: 10,
          date: _ago(15),
        ),
        GradeItemModel(
          title: 'Bonding test',
          category: 'Test',
          score: 31,
          maxScore: 50,
          date: _ago(7),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.arabic,
      items: [
        GradeItemModel(
          title: 'Poetry analysis',
          category: 'Assignment',
          score: 41,
          maxScore: 50,
          date: _ago(5),
        ),
        GradeItemModel(
          title: 'Grammar quiz',
          category: 'Quiz',
          score: 18,
          maxScore: 20,
          date: _ago(14),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.english,
      items: [
        GradeItemModel(
          title: 'Reading test',
          category: 'Test',
          score: 45,
          maxScore: 50,
          date: _ago(10),
        ),
        GradeItemModel(
          title: 'Vocabulary quiz',
          category: 'Quiz',
          score: 19,
          maxScore: 20,
          date: _ago(3),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.islamic,
      items: [
        GradeItemModel(
          title: 'Surat Al-Hujurat summary',
          category: 'Homework',
          score: 18,
          maxScore: 20,
          date: _ago(7),
        ),
      ],
    ),
    SubjectGradesModel(
      subject: MockSubjects.computer,
      items: [
        GradeItemModel(
          title: 'Variables quiz',
          category: 'Quiz',
          score: 10,
          maxScore: 10,
          date: _ago(16),
        ),
        GradeItemModel(
          title: 'Loops exercise',
          category: 'Lab',
          score: 17,
          maxScore: 20,
          date: _ago(8),
        ),
      ],
    ),
  ];
}
