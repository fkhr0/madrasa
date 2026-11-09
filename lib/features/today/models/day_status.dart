import '../../institution/models/holiday_model.dart';
import '../../schedule/models/lesson_model.dart';

/// Where the user is in their school day.
sealed class DayStatus {
  const DayStatus();
}

/// Today is a school day and the first class hasn't started.
class BeforeSchool extends DayStatus {
  final LessonModel firstLesson;
  final int lessonCount;

  const BeforeSchool({required this.firstLesson, required this.lessonCount});
}

/// A class is happening right now.
class InClass extends DayStatus {
  final LessonModel lesson;
  final LessonModel? nextLesson;

  /// 1 for the first period.
  final int period;
  final int lessonCount;

  const InClass({
    required this.lesson,
    required this.nextLesson,
    required this.period,
    required this.lessonCount,
  });
}

/// Between two classes (the break, or a short gap).
class BetweenClasses extends DayStatus {
  final LessonModel nextLesson;
  final int lessonsLeft;

  const BetweenClasses({required this.nextLesson, required this.lessonsLeft});
}

/// Today's classes are over (or there were none), look at the next day.
class SchoolOver extends DayStatus {
  /// Null when there is no school day left in the study year.
  final UpcomingDay? next;

  /// True when today had classes (vs. an ordinary day without lessons).
  final bool hadClassesToday;

  const SchoolOver({required this.next, required this.hadClassesToday});
}

/// No school today: weekend or holiday.
class DayOff extends DayStatus {
  /// Null on a normal weekend.
  final HolidayModel? holiday;
  final UpcomingDay? next;

  const DayOff({required this.holiday, required this.next});
}

/// Before the first day or after the last day of the study year.
class OutsideYear extends DayStatus {
  final bool notStartedYet;
  final DateTime yearStart;

  const OutsideYear({required this.notStartedYet, required this.yearStart});
}

/// The next school day and how it starts.
class UpcomingDay {
  final DateTime date;
  final List<LessonModel> lessons;

  const UpcomingDay({required this.date, required this.lessons});

  LessonModel? get firstLesson => lessons.isEmpty ? null : lessons.first;
}
