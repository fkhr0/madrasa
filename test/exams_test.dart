import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/exams/models/exam_model.dart';
import 'package:school/features/exams/repo/mock_exam_repository.dart';
import 'package:school/features/grades/repo/api_grade_repository.dart';

Map<String, dynamic> _exam({
  required String id,
  required String subjectId,
  required String subjectName,
  String type = 'quiz',
  double maxScore = 20,
  double? score,
  bool published = true,
}) => {
  'id': id,
  'classId': 'cls-5a',
  'className': '5th Scientific – A',
  'type': type,
  'title': '$subjectName $type',
  'date': '2026-11-04',
  'startTime': '09:40',
  'durationMinutes': 30,
  'room': 'Room 204',
  'topics': ['Unit 4'],
  'maxScore': maxScore,
  'published': published,
  'subjectId': subjectId,
  'subjectName': subjectName,
  'icon': 'math',
  'color': 'purple',
  'teacherName': 'Ahmed Kareem',
  'score': score,
};

/// Serves fixed server answers for a student's exams.
class _FixedExams extends MockExamRepository {
  final List<ExamModel> exams;

  _FixedExams(this.exams);

  @override
  Future<List<ExamModel>> getCurrentTerm(String studentId) async => exams;
}

void main() {
  test('an exam from the server', () {
    final exam = ExamModel.fromJson(
      _exam(
        id: 'x1',
        subjectId: 'math',
        subjectName: 'Mathematics',
        type: 'final',
        maxScore: 100,
        score: 87.5,
      ),
    );

    expect(exam.type, ExamType.finalExam);
    expect(exam.start, DateTime(2026, 11, 4, 9, 40));
    expect(exam.subject.teacherName, 'Ahmed Kareem');
    expect(exam.hasResult, isTrue);
    expect(exam.percentage, 87.5);
    expect(ExamType.finalExam.apiName, 'final');
  });

  test('a draft goes to the server with the date and time apart', () {
    final json = ExamDraftModel(
      classId: 'cls-5a',
      subjectId: 'math',
      type: ExamType.midYear,
      title: 'Mid-year exam',
      start: DateTime(2027, 1, 10, 8, 5),
      durationMinutes: 120,
      room: 'Hall A',
      topics: const ['Algebra'],
      maxScore: 100,
    ).toJson();

    expect(json['type'], 'midYear');
    expect(json['date'], '2027-01-10');
    expect(json['startTime'], '08:05');
  });

  test('grades are the published scores, grouped by subject', () async {
    final exams = [
      _exam(id: '1', subjectId: 'math', subjectName: 'Mathematics', score: 18),
      _exam(id: '2', subjectId: 'math', subjectName: 'Mathematics', score: 10),
      _exam(id: '3', subjectId: 'arabic', subjectName: 'Arabic', score: 15),
      // Coming up, or not published: not a grade.
      _exam(
        id: '4',
        subjectId: 'physics',
        subjectName: 'Physics',
        published: false,
      ),
    ].map(ExamModel.fromJson).toList();

    final grades = await ApiGradeRepository(
      _FixedExams(exams),
    ).getCurrentTerm('STU-2026-0142');

    expect(grades.map((g) => g.subject.name), ['Arabic', 'Mathematics']);
    final maths = grades.last;
    expect(maths.items, hasLength(2));
    expect(maths.average, 70); // 28 of 40
  });

  test('mock: schedule, score and delete', () async {
    final repo = MockExamRepository();
    final now = DateTime.now();

    await repo.saveExam(
      ExamDraftModel(
        classId: 'cls-5b',
        subjectId: 'math',
        type: ExamType.quiz,
        title: 'Pop quiz',
        start: DateTime(now.year, now.month, now.day, 8),
        durationMinutes: 20,
        room: '',
        topics: const [],
        maxScore: 10,
      ),
    );
    final quiz = (await repo.getClassExams(
      'cls-5b',
    )).firstWhere((e) => e.title == 'Pop quiz');
    expect(quiz.canBeScored, isTrue);
    expect(quiz.className, '5th Scientific – B');

    final (_, students) = await repo.getScoreSheet(quiz.id);
    await repo.saveScores(quiz.id, {
      students.first.id: 9,
      students[1].id: null,
    });

    final (saved, sheet) = await repo.getScoreSheet(quiz.id);
    expect(saved.published, isTrue);
    expect(saved.scoredCount, 1);
    expect(sheet.first.score, 9);

    await repo.deleteExam(quiz.id);
    expect(
      (await repo.getClassExams('cls-5b')).any((e) => e.id == quiz.id),
      isFalse,
    );
  });
}
