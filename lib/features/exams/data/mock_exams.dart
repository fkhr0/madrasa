import '../../subjects/data/mock_subjects.dart';
import '../models/exam_model.dart';

class MockExams {
  MockExams._();

  static DateTime _day(int offset, int hour, [int minute = 0]) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, hour, minute);
  }

  static List<ExamModel> get items => [
    ExamModel(
      id: 'e1',
      subject: MockSubjects.math,
      type: ExamType.monthly,
      start: _day(5, 8),
      durationMinutes: 90,
      room: 'Hall A',
      topics: const ['Quadratic equations', 'Functions', 'Inequalities'],
    ),
    ExamModel(
      id: 'e2',
      subject: MockSubjects.physics,
      type: ExamType.monthly,
      start: _day(7, 8),
      durationMinutes: 90,
      room: 'Hall A',
      topics: const ['Motion', 'Newton\'s laws', 'Forces'],
    ),
    ExamModel(
      id: 'e3',
      subject: MockSubjects.english,
      type: ExamType.quiz,
      start: _day(2, 10, 45),
      durationMinutes: 30,
      room: 'Room 110',
      topics: const ['Unit 4 vocabulary'],
    ),
    ExamModel(
      id: 'e4',
      subject: MockSubjects.chemistry,
      type: ExamType.monthly,
      start: _day(9, 8),
      durationMinutes: 90,
      room: 'Hall B',
      topics: const ['Periodic table', 'Chemical bonding'],
    ),
    ExamModel(
      id: 'e5',
      subject: MockSubjects.arabic,
      type: ExamType.monthly,
      start: _day(12, 8),
      durationMinutes: 120,
      room: 'Hall A',
      topics: const ['Grammar', 'Poetry', 'Reading comprehension'],
    ),
    // Mid-year exams: fixed dates set by the school for January.
    ExamModel(
      id: 'm1',
      subject: MockSubjects.arabic,
      type: ExamType.midYear,
      start: DateTime(2027, 1, 10, 8),
      durationMinutes: 120,
      room: 'Hall A',
      topics: const ['All first-semester units'],
    ),
    ExamModel(
      id: 'm2',
      subject: MockSubjects.math,
      type: ExamType.midYear,
      start: DateTime(2027, 1, 12, 8),
      durationMinutes: 120,
      room: 'Hall A',
      topics: const ['All first-semester units'],
    ),
    ExamModel(
      id: 'm3',
      subject: MockSubjects.physics,
      type: ExamType.midYear,
      start: DateTime(2027, 1, 14, 8),
      durationMinutes: 120,
      room: 'Hall B',
      topics: const ['All first-semester units'],
    ),
    ExamModel(
      id: 'e6',
      subject: MockSubjects.islamic,
      type: ExamType.quiz,
      start: _day(-10, 9, 40),
      durationMinutes: 30,
      room: 'Room 204',
      topics: const ['Surat Al-Hujurat'],
      score: 17,
      maxScore: 20,
    ),
    ExamModel(
      id: 'e7',
      subject: MockSubjects.computer,
      type: ExamType.quiz,
      start: _day(-16, 9, 40),
      durationMinutes: 30,
      room: 'Computer Lab',
      topics: const ['Variables', 'Conditions'],
      score: 10,
      maxScore: 10,
    ),
    ExamModel(
      id: 'e8',
      subject: MockSubjects.chemistry,
      type: ExamType.quiz,
      start: _day(-15, 8),
      durationMinutes: 30,
      room: 'Lab 1',
      topics: const ['Periodic table'],
      score: 6,
      maxScore: 10,
    ),
  ];
}
