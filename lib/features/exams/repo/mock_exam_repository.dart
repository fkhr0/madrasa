import '../../academics/data/mock_school_classes.dart';
import '../../subjects/data/mock_subjects.dart';
import '../../subjects/models/subject_model.dart';
import '../../teaching/data/mock_teaching.dart';
import '../data/mock_exams.dart';
import '../models/exam_model.dart';
import 'exam_repository.dart';

/// Mock exams (lost on reload). Students see MockExams; staff get an
/// in-memory list per class that starts with the maths exams.
class MockExamRepository implements ExamRepository {
  final _byClass = <String, List<ExamModel>>{};

  /// Exam ID → student ID → score.
  final _scores = <String, Map<String, double>>{};
  int _nextId = 1;

  @override
  Future<List<ExamModel>> getCurrentTerm(String studentId) async =>
      MockExams.items..sort((a, b) => a.start.compareTo(b.start));

  @override
  Future<List<ExamModel>> getClassExams(String classId) async =>
      [..._exams(classId)]..sort((a, b) => a.start.compareTo(b.start));

  List<ExamModel> _exams(String classId) => _byClass.putIfAbsent(classId, () {
    final className = MockSchoolClasses.classes
        .firstWhere((c) => c.id == classId)
        .name;
    return [
      for (final e in MockExams.items)
        if (e.subject.id == MockSubjects.math.id)
          // One copy per class, each with its own ID.
          _copy(
            e,
            id: '${e.id}-$classId',
            classId: classId,
            className: className,
          ),
    ];
  });

  @override
  Future<void> saveExam(ExamDraftModel draft, {String? examId}) async {
    final exams = _exams(draft.classId);
    final old = exams.where((e) => e.id == examId).firstOrNull;
    final exam = ExamModel(
      id: examId ?? 'mock-exam-${_nextId++}',
      subject: _subject(draft.subjectId),
      type: draft.type,
      title: draft.title,
      start: draft.start,
      durationMinutes: draft.durationMinutes,
      room: draft.room,
      topics: draft.topics,
      maxScore: draft.maxScore,
      classId: draft.classId,
      className: old?.className ?? exams.firstOrNull?.className ?? '',
      published: old?.published ?? false,
      scoredCount: old?.scoredCount ?? 0,
    );
    exams
      ..removeWhere((e) => e.id == examId)
      ..add(exam);
  }

  @override
  Future<void> deleteExam(String examId) async {
    for (final exams in _byClass.values) {
      exams.removeWhere((e) => e.id == examId);
    }
    _scores.remove(examId);
  }

  @override
  Future<(ExamModel, List<StudentScoreModel>)> getScoreSheet(
    String examId,
  ) async {
    final exam = _find(examId);
    final scores = _scores[examId] ?? const {};

    return (
      exam,
      [
        for (final s in MockTeaching.studentsOf(exam.classId))
          StudentScoreModel(id: s.id, name: s.name, score: scores[s.id]),
      ],
    );
  }

  @override
  Future<void> saveScores(String examId, Map<String, double?> scores) async {
    final kept = _scores.putIfAbsent(examId, () => {});
    for (final MapEntry(:key, :value) in scores.entries) {
      value == null ? kept.remove(key) : kept[key] = value;
    }
    final exams = _exams(_find(examId).classId);
    final i = exams.indexWhere((e) => e.id == examId);
    exams[i] = _copy(exams[i], published: true, scoredCount: kept.length);
  }

  ExamModel _find(String examId) =>
      _byClass.values.expand((e) => e).firstWhere((e) => e.id == examId);

  static SubjectModel _subject(String id) =>
      MockSubjects.all.firstWhere((s) => s.id == id);

  static ExamModel _copy(
    ExamModel e, {
    String? id,
    String? classId,
    String? className,
    bool? published,
    int? scoredCount,
  }) => ExamModel(
    id: id ?? e.id,
    subject: e.subject,
    type: e.type,
    title: e.title,
    start: e.start,
    durationMinutes: e.durationMinutes,
    room: e.room,
    topics: e.topics,
    maxScore: e.maxScore ?? 100,
    classId: classId ?? e.classId,
    className: className ?? e.className,
    published: published ?? e.published,
    scoredCount: scoredCount ?? e.scoredCount,
  );
}
