import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../institution/models/academic_year_model.dart';
import '../../institution/providers/institution_provider.dart';
import '../../institution/widgets/holiday_banner.dart';
import '../../institution/widgets/year_progress_card.dart';
import '../models/calendar_event_model.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_editor_sheet.dart';
import '../widgets/calendar_event_tile.dart';
import '../widgets/calendar_legend.dart';
import '../widgets/month_calendar.dart';
import '../../../core/l10n/language.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(academicYearProvider);
    final events = ref.watch(calendarEventsProvider);

    final isAdmin = ref.watch(currentUserProvider).role == UserRole.admin;
    final loadedYear = year.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Calendar'))),
      floatingActionButton: isAdmin && loadedYear != null
          ? FloatingActionButton.extended(
              onPressed: () => showEventEditor(
                context,
                year: loadedYear,
                day:
                    ref.read(selectedCalendarDayProvider) ??
                    loadedYear.nextSchoolDay(DateTime.now()),
              ),
              icon: const Icon(Icons.add),
              label: Text(tr('Event')),
            )
          : null,
      body: AsyncValueView(
        value: year,
        onRetry: () => ref.invalidate(academicYearProvider),
        data: (year) => AsyncValueView(
          value: events,
          onRetry: () => ref.invalidate(calendarEventsProvider),
          data: (events) => _Content(year: year, events: events),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final AcademicYearModel year;
  final List<CalendarEventModel> events;

  const _Content({required this.year, required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay =
        ref.watch(selectedCalendarDayProvider) ?? year.clamp(DateTime.now());
    final isAdmin = ref.watch(currentUserProvider).role == UserRole.admin;

    final holiday = year.holidayOn(selectedDay);
    final dayItems = events
        .where(
          (e) => e.type != CalendarEventType.holiday && e.occursOn(selectedDay),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        96, // room for the button
      ),
      children: [
        YearProgressCard(year: year, day: year.clamp(DateTime.now())),
        const SizedBox(height: AppSpacing.md),
        MonthCalendar(
          year: year,
          events: events,
          selectedDay: selectedDay,
          onDaySelected: (day) =>
              ref.read(selectedCalendarDayProvider.notifier).state = day,
        ),
        const SizedBox(height: AppSpacing.md),
        CalendarLegend(types: ref.watch(visibleCalendarTypesProvider)),
        const SizedBox(height: AppSpacing.xl),

        Text(
          DateFormatter.fullDate(selectedDay),
          style: context.text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),

        if (holiday != null) ...[
          HolidayBanner(holiday: holiday),
          const SizedBox(height: AppSpacing.md),
        ],
        if (holiday == null && dayItems.isEmpty)
          Text(
            year.isWorkingDay(selectedDay)
                ? tr('Nothing planned.')
                : tr('Weekend – no classes.'),
            style: context.text.bodyMedium,
          ),
        for (final item in dayItems) ...[
          CalendarEventTile(
            event: item,
            // The administrator taps a school event to change or delete it.
            onTap: isAdmin && item.schoolEvent != null
                ? () => showEventEditor(
                    context,
                    year: year,
                    day: selectedDay,
                    event: item.schoolEvent,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
