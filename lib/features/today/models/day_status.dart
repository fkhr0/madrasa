import '../../institution/models/holiday_model.dart';
import '../../schedule/models/lesson_model.dart';

sealed class DayStatus {
  const DayStatus();
}

class BeforeSchool extends DayStatus {
  final LessonModel firstLesson;
  final int lessonCount;

  const BeforeSchool({required this.firstLesson, required this.lessonCount});
}

class InClass extends DayStatus {
  final LessonModel lesson;
  final LessonModel? nextLesson;

  final int period;
  final int lessonCount;

  const InClass({
    required this.lesson,
    required this.nextLesson,
    required this.period,
    required this.lessonCount,
  });
}

class BetweenClasses extends DayStatus {
  final LessonModel nextLesson;
  final int lessonsLeft;

  const BetweenClasses({required this.nextLesson, required this.lessonsLeft});
}

class SchoolOver extends DayStatus {
  final UpcomingDay? next;

  final bool hadClassesToday;

  const SchoolOver({required this.next, required this.hadClassesToday});
}

class DayOff extends DayStatus {
  final HolidayModel? holiday;
  final UpcomingDay? next;

  const DayOff({required this.holiday, required this.next});
}

class OutsideYear extends DayStatus {
  final bool notStartedYet;
  final DateTime yearStart;

  const OutsideYear({required this.notStartedYet, required this.yearStart});
}

class UpcomingDay {
  final DateTime date;
  final List<LessonModel> lessons;

  const UpcomingDay({required this.date, required this.lessons});

  LessonModel? get firstLesson => lessons.isEmpty ? null : lessons.first;
}
