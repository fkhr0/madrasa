import 'period_model.dart';
import 'timetable_lesson_model.dart';

class ClassTimetableModel {
  final List<PeriodModel> periods;

  final List<int> workingDays;
  final List<TimetableLessonModel> lessons;

  const ClassTimetableModel({
    required this.periods,
    required this.workingDays,
    required this.lessons,
  });

  List<int> get days => [...workingDays]..sort((a, b) => a % 7 - b % 7);

  TimetableLessonModel? lessonAt(int weekday, int period) {
    for (final lesson in lessons) {
      if (lesson.weekday == weekday && lesson.period == period) return lesson;
    }
    return null;
  }

  int lessonsOn(int weekday) =>
      lessons.where((l) => l.weekday == weekday).length;

  factory ClassTimetableModel.fromJson(Map<String, dynamic> json) =>
      ClassTimetableModel(
        periods: [
          for (final p in json['periods'] as List)
            PeriodModel.fromJson(p as Map<String, dynamic>),
        ],
        workingDays: [for (final d in json['workingDays'] as List) d as int],
        lessons: [
          for (final l in json['lessons'] as List)
            TimetableLessonModel.fromJson(l as Map<String, dynamic>),
        ],
      );
}

class WeekTimetableModel {
  final List<PeriodModel> periods;
  final List<TimetableLessonModel> lessons;

  const WeekTimetableModel({required this.periods, required this.lessons});

  List<TimetableLessonModel> lessonsOn(int weekday) =>
      lessons.where((l) => l.weekday == weekday).toList();

  factory WeekTimetableModel.fromJson(Map<String, dynamic> json) =>
      WeekTimetableModel(
        periods: [
          for (final p in json['periods'] as List)
            PeriodModel.fromJson(p as Map<String, dynamic>),
        ],
        lessons: [
          for (final l in json['lessons'] as List)
            TimetableLessonModel.fromJson(l as Map<String, dynamic>),
        ],
      );
}
