import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';

/// A labelled horizontal bar: "5th Scientific – A ▓▓▓▓░░ 72%".
/// Used for simple charts (statistics, fee collection).
class ProgressBarRow extends StatelessWidget {
  final String label;

  /// Shown at the end, e.g. "72%" or "1.2M IQD".
  final String value;

  /// 0–1.
  final double fraction;
  final Color color;

  const ProgressBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(value, style: context.text.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
