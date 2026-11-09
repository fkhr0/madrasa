import '../../institution/models/academic_year_model.dart';
import '../../schedule/models/lesson_model.dart';
import '../models/day_status.dart';

/// Works out the [DayStatus] for [now].
DayStatus resolveDayStatus({
  required DateTime now,
  required AcademicYearModel year,
  required List<LessonModel> todayLessons,
  required UpcomingDay? next,
}) {
  if (!year.contains(now)) {
    return OutsideYear(
      notStartedYet: now.isBefore(year.start),
      yearStart: year.start,
    );
  }

  final holiday = year.holidayOn(now);
  if (holiday != null || !year.isWorkingDay(now)) {
    return DayOff(holiday: holiday, next: next);
  }

  if (todayLessons.isEmpty) {
    return SchoolOver(next: next, hadClassesToday: false);
  }

  if (now.isBefore(todayLessons.first.start)) {
    return BeforeSchool(
      firstLesson: todayLessons.first,
      lessonCount: todayLessons.length,
    );
  }

  for (var i = 0; i < todayLessons.length; i++) {
    final lesson = todayLessons[i];

    if (!now.isBefore(lesson.start) && now.isBefore(lesson.end)) {
      return InClass(
        lesson: lesson,
        nextLesson: i + 1 < todayLessons.length ? todayLessons[i + 1] : null,
        period: i + 1,
        lessonCount: todayLessons.length,
      );
    }

    if (now.isBefore(lesson.start)) {
      return BetweenClasses(
        nextLesson: lesson,
        lessonsLeft: todayLessons.length - i,
      );
    }
  }

  return SchoolOver(next: next, hadClassesToday: true);
}
