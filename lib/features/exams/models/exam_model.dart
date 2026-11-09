import '../../../core/utils/day_json.dart';
import '../../academics/models/subject_style.dart';
import '../../subjects/models/subject_model.dart';
import '../../../core/l10n/language.dart';

/// Exam kinds in Iraqi schools.
enum ExamType {
  /// Short in-class quiz (يومي).
  quiz,

  /// Monthly exam (شهري), usually one round per month.
  monthly,

  /// Mid-year exams (نصف السنة) at the end of the first semester.
  midYear,

  /// End-of-year exams (نهائي).
  finalExam;

  /// The name the server uses ("final" for [finalExam]).
  String get apiName => this == ExamType.finalExam ? 'final' : name;

  static ExamType fromApi(String name) =>
      name == 'final' ? ExamType.finalExam : ExamType.values.byName(name);

  String get label {
    switch (this) {
      case ExamType.quiz:
        return tr('Quiz');
      case ExamType.monthly:
        return tr('Monthly exam');
      case ExamType.midYear:
        return tr('Mid-year exam');
      case ExamType.finalExam:
        return tr('Final exam');
    }
  }
}

class ExamModel {
  final String id;
  final SubjectModel subject;
  final ExamType type;

  /// e.g. "November monthly exam". Empty in older mock data.
  final String title;
  final DateTime start;
  final int durationMinutes;
  final String room;

  /// What the exam covers, e.g. "Chapter 3: Forces".
  final List<String> topics;

  /// The student's score, set once results are published.
  final double? score;

  /// "Out of". Mock data only sets it with a result.
  final double? maxScore;

  /// The class it is for (set by the server).
  final String classId;
  final String className;

  /// Scores are published.
  final bool published;

  /// How many students have a score (staff lists).
  final int scoredCount;

  const ExamModel({
    required this.id,
    required this.subject,
    required this.type,
    this.title = '',
    required this.start,
    required this.durationMinutes,
    required this.room,
    this.topics = const [],
    this.score,
    this.maxScore,
    this.classId = '',
    this.className = '',
    this.published = false,
    this.scoredCount = 0,
  });

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  bool get isUpcoming => DateTime.now().isBefore(end);

  /// Scores can be entered from the exam day on.
  bool get canBeScored {
    final now = DateTime.now();
    return !DateTime(start.year, start.month, start.day).isAfter(now);
  }

  bool get hasResult => score != null && maxScore != null;

  double get percentage => hasResult ? score! / maxScore! * 100 : 0;

  /// The title, or "Mathematics monthly exam" when there is none.
  String get displayTitle =>
      title.isNotEmpty ? title : '${subject.name} ${type.label.toLowerCase()}';

  /// Whole days from today until the exam day (0 = today).
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);

    return day.difference(today).inDays;
  }

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final date = parseDay(json['date'] as String);
    final [hour, minute] = (json['startTime'] as String)
        .split(':')
        .map(int.parse)
        .toList();

    return ExamModel(
      id: json['id'] as String,
      subject: SubjectModel(
        id: json['subjectId'] as String,
        name: json['subjectName'] as String,
        teacherName: json['teacherName'] as String? ?? '',
        icon: SubjectStyle.icon(json['icon'] as String? ?? 'book'),
        color: SubjectStyle.color(json['color'] as String? ?? 'blue'),
      ),
      type: ExamType.fromApi(json['type'] as String),
      title: json['title'] as String,
      start: DateTime(date.year, date.month, date.day, hour, minute),
      durationMinutes: json['durationMinutes'] as int,
      room: json['room'] as String? ?? '',
      topics: [
        for (final t in json['topics'] as List? ?? const []) t as String,
      ],
      score: (json['score'] as num?)?.toDouble(),
      maxScore: (json['maxScore'] as num).toDouble(),
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '',
      published: json['published'] as bool? ?? false,
      scoredCount: json['scoredCount'] as int? ?? 0,
    );
  }
}

/// What a teacher or the office fills in to schedule an exam.
class ExamDraftModel {
  final String classId;
  final String subjectId;
  final ExamType type;
  final String title;

  /// Day and start time.
  final DateTime start;
  final int durationMinutes;
  final String room;
  final List<String> topics;
  final double maxScore;

  const ExamDraftModel({
    required this.classId,
    required this.subjectId,
    required this.type,
    required this.title,
    required this.start,
    required this.durationMinutes,
    required this.room,
    required this.topics,
    required this.maxScore,
  });

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'type': type.apiName,
    'title': title,
    'date': formatDay(start),
    'startTime':
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}',
    'durationMinutes': durationMinutes,
    'room': room,
    'topics': topics,
    'maxScore': maxScore,
  };
}

/// A student on an exam's score sheet.
class StudentScoreModel {
  final String id;
  final String name;

  /// Null = no score (e.g. absent).
  final double? score;

  const StudentScoreModel({required this.id, required this.name, this.score});

  factory StudentScoreModel.fromJson(Map<String, dynamic> json) =>
      StudentScoreModel(
        id: json['id'] as String,
        name: json['name'] as String,
        score: (json['score'] as num?)?.toDouble(),
      );
}
