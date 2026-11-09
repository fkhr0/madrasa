import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';

/// Avatar, name and class at the top of the More page.
class ProfileSummaryCard extends ConsumerWidget {
  const ProfileSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return AppCard(
      onTap: () => context.push(AppRoutes.profile),
      child: Row(
        children: [
          UserAvatar(name: user.name, size: AppSizes.avatarMd + 8),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: context.text.titleMedium),
                Text(user.roleDetail, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
