import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../institution/models/academic_year_model.dart';
import '../models/calendar_event_model.dart';
import '../../../core/l10n/language.dart';

/// Month grid (table_calendar) limited to the study year.
/// Holidays get a green tint, weekends (Fri / Sat) are muted, and each
/// day shows up to 3 dots for the kinds of items on it.
class MonthCalendar extends StatefulWidget {
  final AcademicYearModel year;
  final List<CalendarEventModel> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const MonthCalendar({
    super.key,
    required this.year,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focusedDay = widget.selectedDay;

  /// Holidays are shown by the cell colour, so they get no dot.
  List<CalendarEventModel> _dotsFor(DateTime day) => widget.events
      .where((e) => e.type != CalendarEventType.holiday && e.occursOn(day))
      .toList();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final year = widget.year;

    final dayStyle = text.bodyMedium!.copyWith(color: palette.textPrimary);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: TableCalendar<CalendarEventModel>(
        firstDay: year.start,
        lastDay: year.end,
        focusedDay: _focusedDay,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        weekendDays: const [DateTime.friday, DateTime.saturday],
        availableCalendarFormats: {CalendarFormat.month: tr('Month')},
        selectedDayPredicate: (day) => isSameDay(day, widget.selectedDay),
        holidayPredicate: (day) => year.holidayOn(day) != null,
        eventLoader: _dotsFor,
        onDaySelected: (selected, focused) {
          setState(() => _focusedDay = focused);
          widget.onDaySelected(
            DateTime(selected.year, selected.month, selected.day),
          );
        },
        onPageChanged: (focused) => _focusedDay = focused,

        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: text.titleMedium!,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: palette.textSecondary,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: palette.textSecondary,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: text.labelSmall!.copyWith(color: palette.textSecondary),
          weekendStyle: text.labelSmall!.copyWith(color: palette.textMuted),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: dayStyle,
          weekendTextStyle: dayStyle.copyWith(color: palette.textMuted),
          disabledTextStyle: dayStyle.copyWith(
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          holidayDecoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          holidayTextStyle: dayStyle.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.primary, width: 1.5),
          ),
          todayTextStyle: text.titleSmall!.copyWith(color: palette.primary),
          selectedDecoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: text.titleSmall!.copyWith(
            color: palette.onPrimary,
          ),
        ),

        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;

            final colors = events.map((e) => e.type.color).toSet().take(3);

            return Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in colors)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
