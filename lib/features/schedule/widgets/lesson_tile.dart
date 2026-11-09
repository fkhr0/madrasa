import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/lesson_model.dart';
import '../../../core/l10n/language.dart';

/// Timetable row: period number and times on the left, lesson card on the
/// right. The current lesson is outlined and shows how much time is left.
class LessonTile extends StatelessWidget {
  final LessonModel lesson;

  /// 1 for the first period of the day.
  final int period;

  const LessonTile({super.key, required this.lesson, required this.period});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subject = lesson.subject;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'P$period',
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                Text(
                  DateFormatter.time(lesson.start),
                  style: context.text.titleSmall,
                ),
                Text(
                  DateFormatter.time(lesson.end),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AppCard(
            borderColor: lesson.isNow ? palette.primary : null,
            child: Column(
              children: [
                Row(
                  children: [
                    IconBox(icon: subject.icon, color: subject.color),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Teachers see the class, students the subject.
                          Text(
                            lesson.className ?? subject.name,
                            style: context.text.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.className == null
                                ? '${subject.teacherName} · ${lesson.room}'
                                : '${subject.name} · ${lesson.room}',
                            style: context.text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (lesson.isNow)
                      StatusBadge(label: tr('Now'), color: AppColors.success)
                    else if (lesson.isOver)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: palette.textMuted.withValues(alpha: 0.6),
                      ),
                  ],
                ),
                if (lesson.isNow) _Progress(lesson: lesson),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bar that fills during the lesson, with the minutes left.
class _Progress extends StatelessWidget {
  final LessonModel lesson;

  const _Progress({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final elapsed = now.difference(lesson.start).inMinutes;
    final left = lesson.end.difference(now).inMinutes + 1;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: elapsed / lesson.durationMinutes,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(tr('{0} min left', [left]), style: context.text.labelSmall),
        ],
      ),
    );
  }
}
