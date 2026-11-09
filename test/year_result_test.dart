import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/exams/models/exam_model.dart';
import 'package:school/features/grades/logic/year_result.dart';
import 'package:school/features/institution/models/term_model.dart';
import 'package:school/features/subjects/models/subject_model.dart';

const _math = SubjectModel(
  id: 'math',
  name: 'Mathematics',
  teacherName: '',
  icon: Icons.functions,
  color: Colors.purple,
);

final _terms = [
  TermModel(
    name: 'Second semester',
    start: DateTime(2027, 2, 7),
    end: DateTime(2027, 6, 10),
  ),
  TermModel(
    name: 'First semester',
    start: DateTime(2026, 9, 20),
    end: DateTime(2027, 1, 21),
  ),
];

int _id = 0;
ExamModel _exam(
  ExamType type,
  DateTime day,
  double score, [
  double max = 100,
]) => ExamModel(
  id: 'e${_id++}',
  subject: _math,
  type: type,
  start: day,
  durationMinutes: 60,
  room: '',
  score: score,
  maxScore: max,
);

void main() {
  test('the Iraqi year: terms, mid-year, year work and final', () {
    final exams = [
      _exam(ExamType.monthly, DateTime(2026, 10, 20), 80),
      _exam(ExamType.monthly, DateTime(2026, 11, 20), 45, 50), // 90%
      _exam(ExamType.quiz, DateTime(2026, 11, 3), 2, 10), // doesn't count
      _exam(ExamType.midYear, DateTime(2027, 1, 12), 70),
      _exam(ExamType.monthly, DateTime(2027, 3, 15), 60),
      _exam(ExamType.monthly, DateTime(2027, 4, 15), 80),
      _exam(ExamType.finalExam, DateTime(2027, 6, 5), 66),
    ];

    final r = yearResults(exams, _terms).single;
    expect(r.firstTerm, 85);
    expect(r.midYear, 70);
    expect(r.secondTerm, 70);
    expect(r.yearWork, 75);
    expect(r.finalExam, 66);
    expect(r.result, closeTo(70.5, 0.001));
    expect(r.passed, isTrue);
  });

  test('before the year is over: parts so far, no result yet', () {
    final r = yearResults([
      _exam(ExamType.monthly, DateTime(2026, 10, 20), 40),
      _exam(ExamType.midYear, DateTime(2027, 1, 12), 60),
    ], _terms).single;

    expect(r.secondTerm, isNull);
    expect(r.yearWork, isNull);
    expect(r.yearWorkSoFar, 50);
    expect(r.result, isNull);
    expect(r.passed, isNull);
  });

  test('a fail, and unpublished or quiz-only subjects are left out', () {
    final fail = yearResults([
      _exam(ExamType.monthly, DateTime(2026, 10, 20), 40),
      _exam(ExamType.midYear, DateTime(2027, 1, 12), 45),
      _exam(ExamType.monthly, DateTime(2027, 3, 15), 50),
      _exam(ExamType.finalExam, DateTime(2027, 6, 5), 40),
    ], _terms).single;
    expect(fail.result, closeTo(42.5, 0.001));
    expect(fail.passed, isFalse);

    final none = yearResults([
      _exam(ExamType.quiz, DateTime(2026, 10, 1), 9, 10),
      ExamModel(
        id: 'x',
        subject: _math,
        type: ExamType.monthly,
        start: DateTime(2026, 10, 1),
        durationMinutes: 60,
        room: '',
      ),
    ], _terms);
    expect(none, isEmpty);
  });
}
