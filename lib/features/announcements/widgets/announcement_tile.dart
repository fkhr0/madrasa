import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/announcement_model.dart';

class AnnouncementTile extends StatelessWidget {
  final AnnouncementModel announcement;

  const AnnouncementTile({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final audience = announcement.audience;

    return AppCard(
      onTap: () => context.push(AppRoutes.announcementDetails(announcement.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: audience.icon, color: audience.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: context.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (announcement.isPinned)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.sm,
                        ),
                        child: Icon(
                          Icons.push_pin_outlined,
                          size: 16,
                          color: palette.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  announcement.body,
                  style: context.text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${announcement.authorName} · '
                  '${DateFormatter.shortStamp(announcement.publishedAt)}',
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textMuted,
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
