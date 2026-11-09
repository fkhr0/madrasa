import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../academics/providers/academics_provider.dart';
import '../models/class_timetable_model.dart';
import '../models/period_model.dart';
import '../models/timetable_lesson_model.dart';
import '../providers/timetable_provider.dart';
import '../widgets/lesson_sheet.dart';
import '../../../core/l10n/language.dart';

/// Administrator: a class's week. Pick a day, tap a period to place or
/// change its lesson. The clock button opens the school's bell times.
class ClassTimetablePage extends ConsumerStatefulWidget {
  final String classId;

  const ClassTimetablePage({super.key, required this.classId});

  @override
  ConsumerState<ClassTimetablePage> createState() => _ClassTimetablePageState();
}

class _ClassTimetablePageState extends ConsumerState<ClassTimetablePage> {
  /// Null until the user picks a day; then today if it's a study day,
  /// otherwise the first day of the week.
  int? _day;

  @override
  Widget build(BuildContext context) {
    final schoolClass = ref.watch(schoolClassByIdProvider(widget.classId));
    final timetable = ref.watch(classTimetableProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          schoolClass.valueOrNull == null
              ? tr('Timetable')
              : tr('{0} · Timetable', [schoolClass.valueOrNull!.name]),
        ),
        actions: [
          IconButton(
            tooltip: tr('Bell times'),
            icon: const Icon(Icons.schedule),
            onPressed: () => context.push(AppRoutes.bellTimes),
          ),
        ],
      ),
      body: AsyncValueView(
        value: timetable,
        onRetry: () => ref.invalidate(classTimetableProvider(widget.classId)),
        data: (week) {
          final loadedClass = schoolClass.valueOrNull;
          if (loadedClass == null || week.days.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: tr('No study days'),
              message: tr('Set the study week in the Year tab first.'),
            );
          }
          final today = DateTime.now().weekday;
          final day =
              _day ?? (week.days.contains(today) ? today : week.days.first);

          return Column(
            children: [
              _DayChips(
                week: week,
                selected: day,
                onSelected: (d) => setState(() => _day = d),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  itemCount: week.periods.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final period = week.periods[i];
                    return _PeriodTile(
                      period: period,
                      lesson: week.lessonAt(day, period.number),
                      onTap: () => showLessonSheet(
                        context,
                        schoolClass: loadedClass,
                        timetable: week,
                        weekday: day,
                        period: period,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayChips extends StatelessWidget {
  final ClassTimetableModel week;
  final int selected;
  final ValueChanged<int> onSelected;

  const _DayChips({
    required this.week,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final day in week.days) ...[
            ChoiceChip(
              label: Text(
                '${DateFormatter.weekdayName(day).substring(0, 3)} '
                '· ${week.lessonsOn(day)}',
              ),
              selected: day == selected,
              onSelected: (_) => onSelected(day),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final PeriodModel period;
  final TimetableLessonModel? lesson;
  final VoidCallback onTap;

  const _PeriodTile({
    required this.period,
    required this.lesson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lesson = this.lesson;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: lesson == null ? palette.cardMuted : null,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text('${period.number}', style: context.text.titleMedium),
                Text(period.start, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (lesson == null) ...[
            Icon(Icons.add_circle_outline, color: palette.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                tr('Free · tap to add a lesson'),
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ] else ...[
            IconBox(icon: lesson.icon, color: lesson.color, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.subjectName, style: context.text.titleSmall),
                  Text(
                    [
                      lesson.teacherName ?? tr('No teacher yet'),
                      if (lesson.room.isNotEmpty) lesson.room,
                    ].join(' · '),
                    style: context.text.bodySmall?.copyWith(
                      color: lesson.teacherId == null
                          ? AppColors.warning
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 18, color: palette.textMuted),
          ],
        ],
      ),
    );
  }
}
