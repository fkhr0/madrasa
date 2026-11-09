import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../institution/models/academic_year_model.dart';
import '../../../core/l10n/language.dart';

/// The school days (Sun – Thu) of one week, usually the current one.
/// Every day is tappable; only days outside the study year are faded.
class WeekStrip extends StatelessWidget {
  final AcademicYearModel year;

  /// Any day of the week to show.
  final DateTime week;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const WeekStrip({
    super.key,
    required this.year,
    required this.week,
    required this.selectedDay,
    required this.onDaySelected,
  });

  List<DateTime> get _days {
    final sunday = DateTime(week.year, week.month, week.day - week.weekday % 7);

    return [
      for (var i = 0; i < 7; i++) sunday.add(Duration(days: i)),
    ].where(year.isWorkingDay).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in _days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DayCell(
                day: day,
                isSelected: DateFormatter.isSameDay(day, selectedDay),
                isToday: DateFormatter.isSameDay(day, DateTime.now()),
                isHoliday: year.holidayOn(day) != null,
                isInYear: year.contains(day),
                onTap: () => onDaySelected(day),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isHoliday;
  final bool isInYear;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isHoliday,
    required this.isInYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Pick the cell's colours from its state, most important first.
    final Color background;
    final Color foreground;
    final Color border;

    if (isSelected) {
      background = palette.primary;
      foreground = palette.onPrimary;
      border = palette.primary;
    } else if (isToday) {
      background = palette.primarySoft;
      foreground = palette.onPrimarySoft;
      border = palette.primary.withValues(alpha: 0.4);
    } else if (isHoliday) {
      background = AppColors.success.withValues(alpha: 0.12);
      foreground = AppColors.success;
      border = Colors.transparent;
    } else {
      background = palette.card;
      foreground = palette.textPrimary;
      border = palette.border;
    }

    final label = isToday
        ? tr('Today')
        : isHoliday
        ? tr('Off')
        : null;

    return Opacity(
      opacity: isInYear ? 1 : 0.35,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isInYear ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: [
                Text(
                  DateFormatter.weekdayShort(day),
                  style: context.text.labelMedium?.copyWith(color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: context.text.titleLarge?.copyWith(color: foreground),
                ),
                SizedBox(
                  height: 16,
                  child: label == null
                      ? null
                      : Text(
                          label,
                          style: context.text.labelSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
