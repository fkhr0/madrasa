import '../../../core/utils/day_json.dart';
import '../../attendance/models/attendance_record_model.dart';
import '../../../core/l10n/language.dart';

/// Whether a period is over, going on, or still to come.
enum PeriodState { done, now, later }

/// Attendance a teacher took for one lesson (office and teacher views).
class TakenModel {
  final String? takenBy;
  final DateTime takenAt;
  final int present;
  final int late;
  final int absent;

  const TakenModel({
    this.takenBy,
    required this.takenAt,
    required this.present,
    required this.late,
    required this.absent,
  });

  factory TakenModel.fromJson(Map<String, dynamic> json) => TakenModel(
    takenBy: json['takenBy'] as String?,
    takenAt: DateTime.parse(json['takenAt'] as String).toLocal(),
    present: json['present'] as int? ?? 0,
    late: json['late'] as int? ?? 0,
    absent: json['absent'] as int? ?? 0,
  );
}

/// A student's own mark in one lesson (student and parent views).
class MarkModel {
  final AttendanceStatus status;
  final String? markedBy;
  final DateTime markedAt;

  const MarkModel({
    required this.status,
    this.markedBy,
    required this.markedAt,
  });

  factory MarkModel.fromJson(Map<String, dynamic> json) => MarkModel(
    status: AttendanceStatus.values.byName(json['status'] as String),
    markedBy: json['markedBy'] as String?,
    markedAt: DateTime.parse(json['markedAt'] as String).toLocal(),
  );
}

class DayLessonModel {
  final String classId;
  final String className;
  final String subjectName;
  final String? teacherName;
  final String room;

  /// Office and teacher: the class's attendance (null = not taken).
  final TakenModel? attendance;

  /// Student and parent: their own mark (null = not taken).
  final MarkModel? mark;

  const DayLessonModel({
    required this.classId,
    required this.className,
    required this.subjectName,
    this.teacherName,
    this.room = '',
    this.attendance,
    this.mark,
  });

  factory DayLessonModel.fromJson(Map<String, dynamic> json) => DayLessonModel(
    classId: json['classId'] as String,
    className: json['className'] as String,
    subjectName: json['subjectName'] as String,
    teacherName: json['teacherName'] as String?,
    room: json['room'] as String? ?? '',
    attendance: switch (json['attendance']) {
      final Map<String, dynamic> a => TakenModel.fromJson(a),
      _ => null,
    },
    mark: switch (json['mark']) {
      final Map<String, dynamic> m => MarkModel.fromJson(m),
      _ => null,
    },
  );
}

class DayPeriodModel {
  final int number;

  /// "08:50"
  final String start;
  final String end;
  final PeriodState state;
  final List<DayLessonModel> lessons;

  const DayPeriodModel({
    required this.number,
    required this.start,
    required this.end,
    required this.state,
    required this.lessons,
  });

  factory DayPeriodModel.fromJson(Map<String, dynamic> json) => DayPeriodModel(
    number: json['number'] as int,
    start: json['start'] as String,
    end: json['end'] as String,
    state: PeriodState.values.byName(json['state'] as String),
    lessons: [
      for (final l in json['lessons'] as List)
        DayLessonModel.fromJson(l as Map<String, dynamic>),
    ],
  );
}

/// The office's numbers for the day.
class DayTotalsModel {
  final int students;
  final int present;
  final int absent;
  final int excused;
  final int lessons;
  final int lessonsTaken;

  /// Lessons that started without attendance.
  final int lessonsMissing;
  final int homeworkDue;
  final int exams;
  final int moneyReceived;

  const DayTotalsModel({
    required this.students,
    required this.present,
    required this.absent,
    required this.excused,
    required this.lessons,
    required this.lessonsTaken,
    required this.lessonsMissing,
    required this.homeworkDue,
    required this.exams,
    required this.moneyReceived,
  });

  factory DayTotalsModel.fromJson(Map<String, dynamic> json) {
    int n(String key) => json[key] as int? ?? 0;
    return DayTotalsModel(
      students: n('students'),
      present: n('present'),
      absent: n('absent'),
      excused: n('excused'),
      lessons: n('lessons'),
      lessonsTaken: n('lessonsTaken'),
      lessonsMissing: n('lessonsMissing'),
      homeworkDue: n('homeworkDue'),
      exams: n('exams'),
      moneyReceived: n('moneyReceived'),
    );
  }
}

/// A line under "Homework" or "Exams" on a day.
class DayItemModel {
  final String id;
  final String title;

  /// "5th Scientific – A" (teacher) or "Mathematics" (student).
  final String detail;

  /// "Handed in", "2 to grade", "Scored 18 / 20"...
  final String? status;

  const DayItemModel({
    required this.id,
    required this.title,
    required this.detail,
    this.status,
  });
}

/// A bus trip of the student's line that day.
class DayTripModel {
  final bool toSchool;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool boarded;
  final String busNumber;

  const DayTripModel({
    required this.toSchool,
    required this.startedAt,
    this.endedAt,
    required this.boarded,
    required this.busNumber,
  });
}

/// One day for one role: the office's school, a teacher's lessons, or a
/// student's own day. The parts a role doesn't have stay empty.
class DayModel {
  final DateTime date;
  final bool isToday;
  final bool isSchoolDay;

  /// Why there is no school ("Weekend", a holiday...), or null.
  final String? dayOff;
  final List<DayPeriodModel> periods;

  /// Office only.
  final DayTotalsModel? totals;

  /// Student / parent: the day as a whole, e.g. present, "Missed ...".
  final AttendanceStatus? dayStatus;
  final String? dayNote;
  final String? studentName;

  final List<DayItemModel> homework;
  final List<DayItemModel> exams;
  final List<DayTripModel> bus;

  const DayModel({
    required this.date,
    required this.isToday,
    required this.isSchoolDay,
    this.dayOff,
    this.periods = const [],
    this.totals,
    this.dayStatus,
    this.dayNote,
    this.studentName,
    this.homework = const [],
    this.exams = const [],
    this.bus = const [],
  });

  /// The period going on now, if any.
  DayPeriodModel? get current =>
      periods.where((p) => p.state == PeriodState.now).firstOrNull;

  /// The office's and teacher's view (from /days/:date/school or /teacher).
  factory DayModel.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    final day = json['day'] as Map<String, dynamic>?;
    final isTeacher = student == null && json['totals'] == null;

    String score(Map<String, dynamic> e) {
      final s = e['score'] as num?;
      if (s == null) return e['startTime'] as String? ?? '';
      return tr('Scored {0} / {1}', [_plain(s), _plain(e['maxScore'] as num)]);
    }

    return DayModel(
      date: parseDay(json['date'] as String),
      isToday: json['isToday'] as bool? ?? false,
      isSchoolDay: json['isSchoolDay'] as bool? ?? false,
      dayOff: json['dayOff'] as String?,
      periods: [
        for (final p in json['periods'] as List? ?? const [])
          DayPeriodModel.fromJson(p as Map<String, dynamic>),
      ],
      totals: switch (json['totals']) {
        final Map<String, dynamic> t => DayTotalsModel.fromJson(t),
        _ => null,
      },
      dayStatus: day == null
          ? null
          : AttendanceStatus.values.byName(day['status'] as String),
      dayNote: day?['note'] as String?,
      studentName: student?['name'] as String?,
      homework: [
        for (final h in json['homework'] as List? ?? const [])
          if (h case final Map<String, dynamic> h)
            DayItemModel(
              id: h['id'] as String,
              title: h['title'] as String,
              detail: (isTeacher ? h['className'] : h['subjectName']) as String,
              status: isTeacher
                  ? tr('{0} handed in{1}', [
                      h['handedIn'],
                      (h['toGrade'] as int) > 0
                          ? tr(' · {0} to grade', [h['toGrade']])
                          : '',
                    ])
                  : h['grade'] != null
                  ? tr('Graded {0} / {1}', [
                      _plain(h['grade'] as num),
                      _plain(h['maxGrade'] as num),
                    ])
                  : (h['handedIn'] as bool? ?? false)
                  ? tr('Handed in')
                  : tr('Not handed in yet'),
            ),
      ],
      exams: [
        for (final e in json['exams'] as List? ?? const [])
          if (e case final Map<String, dynamic> e)
            DayItemModel(
              id: e['id'] as String,
              title: e['title'] as String,
              detail: (isTeacher ? e['className'] : e['subjectName']) as String,
              status: isTeacher
                  ? '${e['startTime']}${(e['published'] as bool? ?? false) ? ' · scores published' : ''}'
                  : score(e),
            ),
      ],
      bus: [
        for (final t in json['bus'] as List? ?? const [])
          if (t case final Map<String, dynamic> t)
            DayTripModel(
              toSchool: t['direction'] == 'toSchool',
              startedAt: DateTime.parse(t['startedAt'] as String).toLocal(),
              endedAt: switch (t['endedAt']) {
                final String s => DateTime.parse(s).toLocal(),
                _ => null,
              },
              boarded: t['boarded'] as bool? ?? false,
              busNumber: t['busNumber'] as String? ?? '',
            ),
      ],
    );
  }

  static String _plain(num n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);
}
