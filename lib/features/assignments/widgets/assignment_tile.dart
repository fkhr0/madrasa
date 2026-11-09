import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/assignment_model.dart';
import '../../../core/l10n/language.dart';

/// Assignment card used in the list and on the dashboard.
/// Tapping opens the details page.
class AssignmentTile extends StatelessWidget {
  final AssignmentModel assignment;

  const AssignmentTile({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subject = assignment.subject;

    final dueColor = assignment.isOverdue
        ? AppColors.danger
        : palette.textSecondary;

    return AppCard(
      onTap: () => context.push(AppRoutes.assignmentDetails(assignment.id)),
      child: Row(
        children: [
          IconBox(icon: subject.icon, color: subject.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.name} · ${assignment.type.label}',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: dueColor),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        assignment.status == AssignmentStatus.pending
                            ? DateFormatter.dueLabel(assignment.dueDate)
                            : tr('Due {0}', [
                                DateFormatter.dayMonth(assignment.dueDate),
                              ]),
                        style: context.text.labelSmall?.copyWith(
                          color: dueColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _trailing(context),
        ],
      ),
    );
  }

  /// The grade once graded, otherwise the status badge.
  Widget _trailing(BuildContext context) {
    if (assignment.status == AssignmentStatus.graded &&
        assignment.grade != null) {
      return Text(
        '${assignment.grade!.toStringAsFixed(0)}/${assignment.maxGrade!.toStringAsFixed(0)}',
        style: context.text.titleSmall?.copyWith(color: AppColors.success),
      );
    }

    if (assignment.isOverdue) {
      return StatusBadge(label: tr('Late'), color: AppColors.danger);
    }

    if (assignment.status == AssignmentStatus.pending) {
      return Icon(
        Icons.chevron_right,
        size: AppSizes.iconMd,
        color: context.palette.textMuted,
      );
    }

    return StatusBadge(
      label: assignment.status.label,
      color: assignment.status.color,
    );
  }
}
