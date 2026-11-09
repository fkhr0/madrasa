import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/attendance/models/attendance_record_model.dart';
import 'package:school/features/attendance/models/class_lesson_model.dart';
import 'package:school/features/attendance/repo/mock_attendance_repository.dart';
import 'package:school/features/teaching/models/class_student_model.dart';
import 'package:school/features/teaching/models/teaching_class_model.dart';

void main() {
  group('reading the server', () {
    test('a student day with its lessons', () {
      final day = AttendanceRecordModel.fromJson({
        'date': '2026-11-04',
        'status': 'absent',
        'note': 'Missed 1 of 6 lessons: Physics',
        'lessons': [
          {'period': 3, 'subjectName': 'Physics', 'status': 'absent'},
        ],
      });

      expect(day.date, DateTime(2026, 11, 4));
      expect(day.status, AttendanceStatus.absent);
      expect(day.lessons.single.subjectName, 'Physics');
    });

    test('a class day and a lesson sheet', () {
      final day = ClassDayModel.fromJson({
        'date': '2026-11-08',
        'className': '5th Scientific – A',
        'isSchoolDay': true,
        'lessons': [
          {
            'period': 2,
            'start': '08:50',
            'end': '09:35',
            'subjectName': 'Mathematics',
            'teacherName': 'Ahmed Kareem',
            'taken': true,
          },
        ],
      });
      expect(day.lessons.single.taken, isTrue);

      final notYet = StudentMarkModel.fromJson({
        'id': 'STU-1',
        'name': 'Zainab',
        'status': null,
      });
      final late = StudentMarkModel.fromJson({
        'id': 'STU-1',
        'name': 'Zainab',
        'status': 'late',
      });
      expect(notYet.status, isNull);
      expect(late.status, AttendanceStatus.late);
    });

    test('a teacher class and a student without grades yet', () {
      final c = TeachingClassModel.fromJson({
        'id': 'cls-5a',
        'name': '5th Scientific – A',
        'subject': {
          'id': 'math',
          'name': 'Mathematics',
          'icon': 'math',
          'color': 'purple',
        },
        'room': 'Room 204',
        'studentCount': 5,
      }, teacherName: 'Ahmed Kareem');
      expect(c.subject.teacherName, 'Ahmed Kareem');

      final s = ClassStudentModel.fromJson({
        'id': 'STU-1',
        'name': 'Zainab',
        'attendanceRate': 87.5,
      });
      expect(s.average, isNull);
      expect(s.attendanceRate, 87.5);
    });
  });

  test('mock: marks are kept and excuses change the day', () async {
    final repo = MockAttendanceRepository();
    // A Sunday: Mr. Ahmed teaches 5th A in period 2.
    final sunday = DateTime(2026, 11, 8);

    final day = await repo.getClassDay('cls-5a', sunday);
    final lesson = day.lessons.single;
    expect(lesson.period, 2);
    expect(lesson.taken, isFalse);

    final sheet = await repo.getLessonSheet('cls-5a', sunday, 2);
    await repo.saveLessonMarks('cls-5a', sunday, 2, {
      for (final s in sheet) s.id: AttendanceStatus.late,
    });
    expect(
      (await repo.getClassDay('cls-5a', sunday)).lessons.single.taken,
      isTrue,
    );
    expect(
      (await repo.getLessonSheet('cls-5a', sunday, 2)).first.status,
      AttendanceStatus.late,
    );

    final saturday = await repo.getClassDay('cls-5a', DateTime(2026, 11, 7));
    expect(saturday.isSchoolDay, isFalse);

    const student = 'STU-2026-0142';
    final absent = (await repo.getCurrentTerm(
      student,
    )).firstWhere((r) => r.status == AttendanceStatus.absent);
    await repo.excuseDay(student, absent.date, 'Medical note');
    final excused = (await repo.getCurrentTerm(
      student,
    )).firstWhere((r) => r.date == absent.date);
    expect(excused.status, AttendanceStatus.excused);
    expect(excused.note, 'Medical note');

    await repo.removeExcuse(student, absent.date);
    expect(
      (await repo.getCurrentTerm(
        student,
      )).firstWhere((r) => r.date == absent.date).status,
      AttendanceStatus.absent,
    );
  });
}
