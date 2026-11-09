import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/calendar_event_model.dart';
import '../../../core/l10n/language.dart';

class CalendarEventTile extends StatelessWidget {
  final CalendarEventModel event;

  /// Replaces the default tap (opening [CalendarEventModel.route]),
  /// e.g. the administrator editing a school event.
  final VoidCallback? onTap;

  const CalendarEventTile({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final time = event.isAllDay
        ? tr('All day')
        : DateFormatter.time(event.start);

    return AppCard(
      onTap:
          onTap ??
          (event.route == null ? null : () => context.push(event.route!)),
      child: Row(
        children: [
          IconBox(icon: type.icon, color: type.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  event.subtitle == null ? time : '$time · ${event.subtitle}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          StatusBadge(label: type.label, color: type.color),
        ],
      ),
    );
  }
}
