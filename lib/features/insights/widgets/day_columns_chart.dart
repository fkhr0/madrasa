import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../models/insights_model.dart';

/// Small column chart for rates (0–1) by day. The lowest day is
/// highlighted so the eye goes there first.
class DayColumnsChart extends StatelessWidget {
  final List<LabeledValue> days;

  /// Columns start from this rate, so small differences are visible.
  final double floor;

  const DayColumnsChart({super.key, required this.days, this.floor = 0.7});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lowest = days.reduce((a, b) => a.value <= b.value ? a : b);
    const height = 96.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Column(
              children: [
                Text(
                  '${(day.value * 100).round()}',
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  height:
                      height *
                      ((day.value - floor) / (1 - floor)).clamp(0.05, 1.0),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: identical(day, lowest)
                        ? palette.primary.withValues(alpha: 0.35)
                        : palette.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(day.label, style: context.text.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
