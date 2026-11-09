import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/announcement_provider.dart';
import '../widgets/announcement_tile.dart';
import '../../../core/l10n/language.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(announcementsProvider);
    final role = ref.watch(currentUserProvider).role;
    final canPublish = role == UserRole.teacher || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Announcements'))),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.newAnnouncement),
              icon: const Icon(Icons.edit_outlined),
              label: Text(tr('New')),
            )
          : null,
      body: AsyncValueView(
        value: announcements,
        onRetry: () => ref.invalidate(announcementsProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: tr('No announcements yet'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              96, // room for the button
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => AnnouncementTile(announcement: items[i]),
          );
        },
      ),
    );
  }
}
