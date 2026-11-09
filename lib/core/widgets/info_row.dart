import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';

/// Icon + label + value on one line, used in detail and profile pages.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: context.palette.textMuted),
          const SizedBox(width: AppSpacing.md),
          // Long labels shrink instead of overflowing on small phones.
          Flexible(
            child: Text(
              label,
              style: context.text.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              value,
              style: context.text.titleSmall,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
