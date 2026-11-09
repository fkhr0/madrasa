import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/l10n/language.dart';

/// The gap between two periods (الفرصة), drawn as a quiet dashed line.
class BreakTile extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const BreakTile({super.key, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final minutes = end.difference(start).inMinutes;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 56),
      child: Row(
        children: [
          Icon(Icons.coffee_outlined, size: 16, color: palette.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            tr('Break · {0} min · {1}', [minutes, DateFormatter.time(start)]),
            style: context.text.labelSmall?.copyWith(color: palette.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(color: palette.border)),
        ],
      ),
    );
  }
}
