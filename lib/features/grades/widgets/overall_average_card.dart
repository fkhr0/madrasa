import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/l10n/language.dart';

/// Big number at the top of the Grades page.
class OverallAverageCard extends StatelessWidget {
  final double average;
  final int subjectCount;

  const OverallAverageCard({
    super.key,
    required this.average,
    required this.subjectCount,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = GradeScale.colorFor(average);

    return AppCard(
      color: palette.primarySoft,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: average / 100,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: palette.card,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '${average.round()}%',
                    style: context.text.titleMedium?.copyWith(
                      color: palette.onPrimarySoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Term average · {0}', [GradeScale.labelFor(average)]),
                  style: context.text.titleMedium?.copyWith(
                    color: palette.onPrimarySoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr('Across {0} subjects this term', [subjectCount]),
                  style: context.text.bodySmall?.copyWith(
                    color: palette.onPrimarySoft.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
