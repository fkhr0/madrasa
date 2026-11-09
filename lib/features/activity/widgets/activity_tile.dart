import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/open_route.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/activity_item_model.dart';

/// One line of activity: what kind, what happened, when (and the day, for
/// older lines). Tapping opens what it is about.
class ActivityTile extends StatelessWidget {
  final ActivityItemModel item;

  /// Show the date too (lists that span several days).
  final bool showDay;

  const ActivityTile({super.key, required this.item, this.showDay = true});

  @override
  Widget build(BuildContext context) {
    final when = showDay && !DateFormatter.isSameDay(item.at, DateTime.now())
        ? '${DateFormatter.relativeDay(item.at)} · ${DateFormatter.time(item.at)}'
        : DateFormatter.time(item.at);

    return InkWell(
      onTap: item.route == null ? null : () => context.openRoute(item.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(icon: item.kind.icon, color: item.kind.color, size: 34),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.summary, style: context.text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$when · ${item.kind.label}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
