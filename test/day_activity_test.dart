import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/activity/models/activity_item_model.dart';
import 'package:school/features/attendance/models/attendance_record_model.dart';
import 'package:school/features/days/models/day_model.dart';

void main() {
  test('the office day: periods, who took attendance, totals', () {
    final day = DayModel.fromJson({
      'date': '2026-11-05',
      'isToday': false,
      'isSchoolDay': true,
      'dayOff': null,
      'periods': [
        {
          'number': 1,
          'start': '08:00',
          'end': '08:45',
          'state': 'done',
          'lessons': [
            {
              'classId': 'cls-5a',
              'className': '5th Scientific – A',
              'subjectName': 'Islamic Education',
              'teacherName': 'Yusuf Ali',
              'room': 'Room 204',
              'attendance': {
                'takenBy': 'Yusuf Ali',
                'takenAt': '2026-11-05T05:05:00.000Z',
                'present': 30,
                'late': 1,
                'absent': 1,
              },
            },
            {
              'classId': 'cls-5b',
              'className': '5th Scientific – B',
              'subjectName': 'Physics',
              'attendance': null,
            },
          ],
        },
      ],
      'totals': {
        'students': 40,
        'present': 38,
        'absent': 2,
        'excused': 1,
        'lessons': 24,
        'lessonsTaken': 6,
        'lessonsMissing': 18,
        'homeworkDue': 1,
        'exams': 0,
        'moneyReceived': 250000,
      },
    });

    expect(day.periods.single.state, PeriodState.done);
    final lessons = day.periods.single.lessons;
    expect(lessons.first.attendance!.takenBy, 'Yusuf Ali');
    expect(lessons.first.attendance!.absent, 1);
    expect(lessons.last.attendance, isNull);
    expect(day.totals!.lessonsMissing, 18);
  });

  test("a student's day: own marks, homework, exams, bus", () {
    final day = DayModel.fromJson({
      'date': '2026-11-05',
      'isToday': true,
      'isSchoolDay': true,
      'student': {'id': 'STU-2026-0142', 'name': 'Zainab Haider'},
      'day': {'status': 'present', 'note': 'Missed 1 of 6 lessons: Physics'},
      'periods': [
        {
          'number': 3,
          'start': '09:40',
          'end': '10:25',
          'state': 'now',
          'lessons': [
            {
              'classId': 'cls-5a',
              'className': '5th Scientific – A',
              'subjectName': 'Physics',
              'mark': {
                'status': 'absent',
                'markedBy': 'Sara Hadi',
                'markedAt': '2026-11-05T06:45:00.000Z',
              },
            },
          ],
        },
      ],
      'homework': [
        {
          'id': 'w1',
          'title': 'Worksheet 4',
          'subjectName': 'Mathematics',
          'handedIn': true,
          'grade': null,
          'maxGrade': 10,
        },
      ],
      'exams': [
        {
          'id': 'e1',
          'title': 'Quiz',
          'subjectName': 'English',
          'startTime': '10:45',
          'score': 18,
          'maxScore': 20,
        },
      ],
      'bus': [
        {
          'direction': 'toSchool',
          'startedAt': '2026-11-05T04:00:00.000Z',
          'endedAt': '2026-11-05T04:40:00.000Z',
          'boarded': true,
          'busNumber': '12',
        },
      ],
    });

    expect(day.studentName, 'Zainab Haider');
    expect(day.dayStatus, AttendanceStatus.present);
    expect(day.current?.number, 3);
    expect(
      day.periods.single.lessons.single.mark!.status,
      AttendanceStatus.absent,
    );
    expect(day.homework.single.status, 'Handed in');
    expect(day.exams.single.status, 'Scored 18 / 20');
    expect(day.bus.single.boarded, isTrue);
  });

  test('activity filters become the server query, and compare by value', () {
    final filter = ActivityFilter(
      date: DateTime(2026, 11, 5),
      kinds: const {ActivityKind.attendance, ActivityKind.grades},
      classId: 'cls-5a',
      query: ' absent ',
    );
    expect(filter.toQuery(), {
      'date': '2026-11-05',
      'kind': 'attendance,grades',
      'classId': 'cls-5a',
      'q': 'absent',
    });
    expect(
      filter,
      ActivityFilter(
        date: DateTime(2026, 11, 5),
        kinds: const {ActivityKind.grades, ActivityKind.attendance},
        classId: 'cls-5a',
        query: ' absent ',
      ),
    );
    expect(const ActivityFilter().isEmpty, isTrue);
    expect(ActivityKind.fromName('unknown'), ActivityKind.announcement);
  });
}
