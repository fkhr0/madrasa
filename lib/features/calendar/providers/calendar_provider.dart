import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import '../../assignments/models/assignment_model.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../exams/models/exam_model.dart';
import '../../exams/providers/exam_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/calendar_event_model.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../models/school_event_model.dart';
import '../repo/api_calendar_repository.dart';
import '../repo/calendar_repository.dart';
import '../repo/mock_calendar_repository.dart';
import '../../../core/l10n/language.dart';

/// The server when API_URL is set, otherwise the mock events.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => AppConfig.useApi
      ? ApiCalendarRepository(watchApi(ref))
      : MockCalendarRepository(),
);

/// The day tapped on the calendar. Null until the user taps one,
/// then the page shows today (kept inside the study year).
final selectedCalendarDayProvider = StateProvider<DateTime?>((ref) => null);

/// The kinds of items the signed-in user sees (and the legend shows).
final visibleCalendarTypesProvider = Provider<List<CalendarEventType>>(
  (ref) => CalendarEventType.visibleFor(ref.watch(currentUserProvider).role),
);

/// Everything on the calendar in one list, for the signed-in user's role.
final calendarEventsProvider = FutureProvider<List<CalendarEventModel>>((
  ref,
) async {
  final role = ref.watch(currentUserProvider).role;
  final visible = ref.watch(visibleCalendarTypesProvider);
  final year = await ref.watch(academicYearProvider.future);

  bool shows(CalendarEventType type) => visible.contains(type);

  final events = <CalendarEventModel>[
    for (final event
        in await ref.watch(calendarRepositoryProvider).getSchoolEvents(role))
      event.toCalendarEvent(),

    for (final holiday in year.holidays)
      CalendarEventModel(
        id: 'holiday-${holiday.start}',
        title: holiday.name,
        type: CalendarEventType.holiday,
        start: holiday.start,
        endDay: holiday.end,
        isAllDay: true,
        subtitle: holiday.lengthInDays > 1
            ? tr('{0} days off', [holiday.lengthInDays])
            : tr('Day off'),
      ),
  ];

  // Students and parents: the student's homework and exams.
  if (shows(CalendarEventType.homework)) {
    final assignments = await ref.watch(assignmentsProvider.future);
    final exams = await ref.watch(examsProvider.future);

    events.addAll([
      for (final assignment in assignments)
        CalendarEventModel(
          id: 'due-${assignment.id}',
          title: assignment.title,
          type: _typeOf(assignment),
          start: assignment.dueDate,
          subtitle: '${assignment.subject.name} · ${assignment.status.label}',
          route: AppRoutes.assignmentDetails(assignment.id),
        ),
      for (final exam in exams)
        CalendarEventModel(
          id: 'exam-${exam.id}',
          title: '${exam.subject.name} – ${exam.type.label}',
          type: exam.type == ExamType.quiz
              ? CalendarEventType.quiz
              : CalendarEventType.exam,
          start: exam.start,
          subtitle: exam.room,
          route: AppRoutes.exams,
        ),
    ]);
  }

  // Students only: their own reminders.
  if (shows(CalendarEventType.reminder) && role == UserRole.student) {
    final tasks = await ref.watch(tasksProvider.future);

    events.addAll([
      for (final task in tasks.where((t) => !t.isDone))
        CalendarEventModel(
          id: 'task-${task.id}',
          title: task.title,
          type: CalendarEventType.reminder,
          start: task.dueAt,
          route: AppRoutes.tasks,
        ),
    ]);
  }

  // Only what falls inside the study year and this role may see.
  return events.where((e) => shows(e.type) && year.contains(e.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
});

CalendarEventType _typeOf(AssignmentModel assignment) {
  switch (assignment.type) {
    case AssignmentType.homework:
      return CalendarEventType.homework;
    case AssignmentType.quiz:
      return CalendarEventType.quiz;
    case AssignmentType.assignment:
    case AssignmentType.project:
      return CalendarEventType.assignment;
  }
}

final calendarActionsProvider = Provider<CalendarActions>(CalendarActions.new);

/// Administrator: change the school calendar. Each change reloads it.
class CalendarActions {
  final Ref _ref;

  CalendarActions(this._ref);

  Future<void> saveEvent(SchoolEventModel event) async {
    await _ref.read(calendarRepositoryProvider).saveEvent(event);
    _ref.invalidate(calendarEventsProvider);
  }

  Future<void> deleteEvent(SchoolEventModel event) async {
    await _ref.read(calendarRepositoryProvider).deleteEvent(event.id);
    _ref.invalidate(calendarEventsProvider);
  }
}
