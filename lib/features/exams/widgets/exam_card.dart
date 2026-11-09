import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tasks/widgets/reminder_sheet.dart';
import '../models/exam_model.dart';
import '../../../core/l10n/language.dart';

/// Upcoming exam: date, subject, time, room, countdown and topics.
class ExamCard extends StatelessWidget {
  final ExamModel exam;

  /// Students get a "Remind me to study" button.
  final bool showReminder;

  const ExamCard({super.key, required this.exam, this.showReminder = false});

  /// Closer exams get a warmer colour.
  Color get _countdownColor {
    if (exam.daysLeft <= 2) return AppColors.danger;
    if (exam.daysLeft <= 6) return AppColors.warning;

    return AppColors.info;
  }

  String get _countdownLabel {
    final days = exam.daysLeft;
    if (days <= 0) return tr('Today');
    if (days == 1) return tr('Tomorrow');

    return tr('In {0} days', [days]);
  }

  @override
  Widget build(BuildContext context) {
    final subject = exam.subject;
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateBlock(date: exam.start, color: subject.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${exam.type.label} · ${DateFormatter.time(exam.start)}'
                      ' – ${DateFormatter.time(exam.end)}',
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            exam.room,
                            style: context.text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(label: _countdownLabel, color: _countdownColor),
            ],
          ),
          if (showReminder)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => showReminderSheet(
                  context,
                  title: tr('Study for {0}', [exam.subject.name]),
                  before: exam.start,
                  route: AppRoutes.exams,
                ),
                icon: const Icon(Icons.alarm_add, size: 16),
                label: Text(tr('Remind me to study')),
              ),
            ),
          if (exam.topics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final topic in exam.topics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.cardMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(topic, style: context.text.bodySmall),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
