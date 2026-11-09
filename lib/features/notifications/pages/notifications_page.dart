import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/open_route.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';
import '../widgets/phone_notifications_card.dart';
import '../../../core/l10n/language.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Notifications')),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(markAllNotificationsReadProvider)(),
              child: Text(tr('Mark all read')),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AsyncValueView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                PhoneNotificationsCard(),
                EmptyState(
                  icon: Icons.notifications_none,
                  title: tr('You\'re all caught up'),
                ),
              ],
            );
          }

          final today = items
              .where(
                (n) => DateFormatter.isSameDay(n.createdAt, DateTime.now()),
              )
              .toList();
          final earlier = items.where((n) => !today.contains(n)).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              const PhoneNotificationsCard(),
              if (today.isNotEmpty) ..._group(context, ref, tr('Today'), today),
              if (earlier.isNotEmpty)
                ..._group(context, ref, tr('Earlier'), earlier),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<NotificationModel> items,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.xs,
        ),
        child: Text(
          title.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ),
      for (final notification in items)
        NotificationTile(
          notification: notification,
          onTap: () {
            ref.read(markNotificationReadProvider)(notification.id);
            final route = notification.route;
            if (route != null) context.openRoute(route);
          },
        ),
    ];
  }
}
