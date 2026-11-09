import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/section_header.dart';
import '../../announcements/providers/announcement_provider.dart';
import '../../announcements/widgets/announcement_tile.dart';
import '../../../core/l10n/language.dart';

/// The 2 most important announcements (pinned first).
class LatestAnnouncementsSection extends ConsumerWidget {
  const LatestAnnouncementsSection({super.key});

  static const _maxItems = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(announcementsProvider).valueOrNull ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: tr('Announcements'),
          onSeeAll: () => context.push(AppRoutes.announcements),
        ),
        for (final announcement in items.take(_maxItems)) ...[
          AnnouncementTile(announcement: announcement),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
