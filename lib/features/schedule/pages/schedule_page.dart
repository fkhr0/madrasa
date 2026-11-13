import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../institution/models/academic_year_model.dart';
import '../../institution/providers/institution_provider.dart';
import '../../institution/widgets/holiday_banner.dart';
import '../../today/models/day_status.dart';
import '../../today/providers/today_provider.dart';
import '../models/lesson_model.dart';
import '../providers/schedule_provider.dart';
import '../widgets/break_tile.dart';
import '../widgets/lesson_tile.dart';
import '../widgets/week_strip.dart';
import '../../../core/l10n/language.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(academicYearProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Schedule'))),
      body: AsyncValueView(
        value: year,
        onRetry: () => ref.invalidate(academicYearProvider),
        data: (year) => _Content(year: year),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final AcademicYearModel year;

  const _Content({required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(selectedDayProvider);
    final status = ref.watch(dayStatusProvider).valueOrNull;
    final (smartDay, note) = _smartDefault(year, status);

    // A day picked on another day may be in an old week: ignore it then.
    final pickedThisWeek =
        picked != null && _sundayOf(picked) == _sundayOf(smartDay);
    final selectedDay = pickedThisWeek ? picked : smartDay;
    final lessons = ref.watch(lessonsForDayProvider(selectedDay));

    void select(DateTime day) =>
        ref.read(selectedDayProvider.notifier).state = day;

    return Column(
      children: [
        // The timetable is the same every week, so there is no week to
        // browse: just the days of this school week.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page - 3,
            AppSpacing.sm,
            AppSpacing.page - 3,
            0,
          ),
          child: WeekStrip(
            year: year,
            week: smartDay,
            selectedDay: selectedDay,
            onDaySelected: select,
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: lessons,
            onRetry: () => ref.invalidate(lessonsForDayProvider(selectedDay)),
            data: (lessons) => _DayView(
              year: year,
              day: selectedDay,
              lessons: lessons,
              note: pickedThisWeek ? null : note,
            ),
          ),
        ),
      ],
    );
  }
}

DateTime _sundayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - d.weekday % 7);

/// The day the Schedule tab opens on, and why (shown as a small note).
/// After today's last class it jumps to the next school day.
(DateTime, String?) _smartDefault(AcademicYearModel year, DayStatus? status) {
  final today = year.nextSchoolDay(DateTime.now());

  switch (status) {
    case SchoolOver(next: final next?, hadClassesToday: true):
      return (
        next.date,
        tr('Today\'s classes are over. Showing the next school day.'),
      );
    case DayOff(next: final next?):
      return (next.date, tr('No school today. Showing the next school day.'));
    default:
      return (today, null);
  }
}

class _DayView extends StatelessWidget {
  final AcademicYearModel year;
  final DateTime day;
  final List<LessonModel> lessons;

  /// Why this day was opened automatically, if it was.
  final String? note;

  const _DayView({
    required this.year,
    required this.day,
    required this.lessons,
    this.note,
  });

  /// A gap this long between two periods is shown as a break.
  static const _minBreakMinutes = 15;

  @override
  Widget build(BuildContext context) {
    final holiday = year.holidayOn(day);

    if (holiday != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [HolidayBanner(holiday: holiday)],
      );
    }

    if (lessons.isEmpty) {
      return EmptyState(
        icon: Icons.weekend_outlined,
        title: tr('No classes'),
        message: tr('Enjoy your day.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        if (note != null) ...[
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(note!, style: context.text.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(DateFormatter.fullDate(day), style: context.text.titleMedium),
        Text(
          tr('{0} classes · {1} – {2}', [
            lessons.length,
            DateFormatter.time(lessons.first.start),
            DateFormatter.time(lessons.last.end),
          ]),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < lessons.length; i++) ...[
          if (i > 0 &&
              lessons[i].start.difference(lessons[i - 1].end).inMinutes >=
                  _minBreakMinutes) ...[
            BreakTile(start: lessons[i - 1].end, end: lessons[i].start),
            const SizedBox(height: AppSpacing.md),
          ],
          LessonTile(lesson: lessons[i], period: i + 1),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
