import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../providers/announcement_provider.dart';
import '../widgets/announcement_menu.dart';
import '../../../core/l10n/language.dart';
import '../../../core/utils/text_direction.dart';

class AnnouncementDetailsPage extends ConsumerWidget {
  final String announcementId;

  const AnnouncementDetailsPage({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = ref.watch(announcementByIdProvider(announcementId));

    final loaded = announcement.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [if (loaded != null) AnnouncementMenu(announcement: loaded)],
      ),
      body: AsyncValueView(
        value: announcement,
        data: (announcement) {
          if (announcement == null) {
            return EmptyState(
              icon: Icons.search_off,
              title: tr('Announcement not found'),
            );
          }

          final audience = announcement.audience;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  label: announcement.audienceLabel,
                  color: audience.color,
                  icon: audience.icon,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                announcement.title,
                textDirection: directionOf(announcement.title),
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  UserAvatar(name: announcement.authorName, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.authorName,
                        style: context.text.titleSmall,
                      ),
                      Text(
                        tr('{0} at {1}', [
                          DateFormatter.relativeDay(announcement.publishedAt),
                          DateFormatter.time(announcement.publishedAt),
                        ]),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                announcement.body,
                textDirection: directionOf(announcement.body),
                style: context.text.bodyLarge,
              ),
            ],
          );
        },
      ),
    );
  }
}
