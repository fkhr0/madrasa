import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../../core/l10n/language.dart';

/// Date, greeting, bell (with unread dot) and the profile avatar.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return tr('Good morning');
    if (hour < 17) return tr('Good afternoon');

    return tr('Good evening');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final year = ref.watch(academicYearProvider).valueOrNull;
    final today = DateTime.now();

    // "Wednesday, 4 November · Week 7" during the study year.
    final dateLine = year != null && year.contains(today)
        ? tr('{0} · Week {1}', [
            DateFormatter.fullDate(today),
            year.weekNumber(today),
          ])
        : DateFormatter.fullDate(today);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLine, style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_greeting()}, ${user.firstName}',
                style: context.text.headlineSmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            smallSize: 8,
            backgroundColor: context.palette.primary,
            child: const Icon(Icons.notifications_none),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: () => context.push(AppRoutes.profile),
          child: UserAvatar(name: user.name),
        ),
      ],
    );
  }
}
