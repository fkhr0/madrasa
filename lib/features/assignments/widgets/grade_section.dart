import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../models/assignment_model.dart';
import '../../../core/l10n/language.dart';

/// The mark and the teacher's comment, shown once an assignment is graded.
class GradeSection extends StatelessWidget {
  final AssignmentModel assignment;

  const GradeSection({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final grade = assignment.grade!;
    final maxGrade = assignment.maxGrade!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('Grade'), style: context.text.titleMedium),
              ),
              Text(
                grade.toStringAsFixed(0),
                style: context.text.headlineSmall?.copyWith(
                  color: AppColors.success,
                ),
              ),
              Text(
                ' / ${maxGrade.toStringAsFixed(0)}',
                style: context.text.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: grade / maxGrade,
              minHeight: 6,
              color: AppColors.success,
            ),
          ),
          if (assignment.feedback != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Teacher\'s feedback'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(assignment.feedback!, style: context.text.bodyLarge),
          ],
        ],
      ),
    );
  }
}
