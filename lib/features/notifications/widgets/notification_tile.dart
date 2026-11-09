import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/notification_model.dart';
import '../../../core/utils/text_direction.dart';

/// Unread notifications have a tinted background and a dot.
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = notification.type;

    return Material(
      color: notification.isRead
          ? Colors.transparent
          : palette.primarySoft.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(icon: type.icon, color: type.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      textDirection: directionOf(notification.title),
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      textDirection: directionOf(notification.body),
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormatter.shortStamp(notification.createdAt),
                      style: context.text.labelSmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsetsDirectional.only(
                    top: 6,
                    start: AppSpacing.sm,
                  ),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
