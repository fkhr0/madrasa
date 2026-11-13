import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/day_model.dart';
import '../../../core/l10n/language.dart';

/// One period of the day with its lessons.
class PeriodCard extends StatelessWidget {
  final DayPeriodModel period;

  /// Tapping a lesson (e.g. to take its attendance).
  final void Function(DayLessonModel lesson)? onLessonTap;

  /// Student view: show the mark instead of the class's attendance.
  final bool ownMarks;

  const PeriodCard({
    super.key,
    required this.period,
    this.onLessonTap,
    this.ownMarks = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (stateLabel, stateColor) = switch (period.state) {
      PeriodState.done => (tr('Done'), palette.textMuted),
      PeriodState.now => (tr('Now'), AppColors.success),
      PeriodState.later => (tr('Later'), AppColors.info),
    };
    final taken = period.lessons.where((l) => l.attendance != null).length;

    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: period.state == PeriodState.now ? AppColors.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  tr('Period {0}', [period.number]),
                  style: context.text.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${period.start} – ${period.end}',
                  style: context.text.bodySmall,
                ),
                const Spacer(),
                if (!ownMarks && period.lessons.length > 1)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: Text(
                      tr('{0}/{1} taken', [taken, period.lessons.length]),
                      style: context.text.labelSmall,
                    ),
                  ),
                StatusBadge(label: stateLabel, color: stateColor),
              ],
            ),
          ),
          for (final lesson in period.lessons)
            InkWell(
              onTap: onLessonTap == null ? null : () => onLessonTap!(lesson),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownMarks
                                ? lesson.subjectName
                                : '${lesson.className} · ${lesson.subjectName}',
                            style: context.text.bodyMedium,
                          ),
                          Text(
                            [
                              lesson.teacherName ?? tr('No teacher yet'),
                              if (lesson.room.isNotEmpty) lesson.room,
                            ].join(' · '),
                            style: context.text.labelSmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ownMarks
                        ? _OwnMark(lesson: lesson, state: period.state)
                        : _Taken(lesson: lesson, state: period.state),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// "08:05 · Ahmed Kareem · 2 absent", or "Not taken" once it started.
class _Taken extends StatelessWidget {
  final DayLessonModel lesson;
  final PeriodState state;

  const _Taken({required this.lesson, required this.state});

  @override
  Widget build(BuildContext context) {
    final taken = lesson.attendance;
    if (taken == null) {
      return state == PeriodState.later
          ? Text('–', style: context.text.labelMedium)
          : StatusBadge(label: tr('Not taken'), color: AppColors.danger);
    }
    final missing = taken.absent + taken.late;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        StatusBadge(
          label: missing == 0
              ? tr('All present')
              : tr('{0} absent{1}', [
                  taken.absent,
                  taken.late > 0 ? tr(' · {0} late', [taken.late]) : '',
                ]),
          color: taken.absent > 0 ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(height: 2),
        Text(
          '${DateFormatter.time(taken.takenAt)}'
          '${taken.takenBy == null ? '' : ' · ${taken.takenBy}'}',
          style: context.text.labelSmall,
        ),
      ],
    );
  }
}

/// The student's own mark: present / late / absent, by whom and when.
class _OwnMark extends StatelessWidget {
  final DayLessonModel lesson;
  final PeriodState state;

  const _OwnMark({required this.lesson, required this.state});

  @override
  Widget build(BuildContext context) {
    final mark = lesson.mark;
    if (mark == null) {
      return Text(
        state == PeriodState.later ? '–' : tr('Not taken yet'),
        style: context.text.labelSmall,
      );
    }
    final status = mark.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        StatusBadge(label: status.label, color: status.color),
        const SizedBox(height: 2),
        Text(
          '${DateFormatter.time(mark.markedAt)}'
          '${mark.markedBy == null ? '' : ' · ${mark.markedBy}'}',
          style: context.text.labelSmall,
        ),
      ],
    );
  }
}
