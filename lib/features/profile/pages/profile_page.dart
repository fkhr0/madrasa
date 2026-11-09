import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/language.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final groupLabel = tr('Class');

    return Scaffold(
      appBar: AppBar(title: Text(tr('Profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: UserAvatar(name: user.name, size: AppSizes.avatarLg),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            user.name,
            style: context.text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.roleDetail,
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: tr('School ID'),
                  value: user.id,
                ),
                if (user.className != null)
                  InfoRow(
                    icon: Icons.groups_outlined,
                    label: groupLabel,
                    value: user.className!,
                  ),
                if (user.subjectName != null)
                  InfoRow(
                    icon: Icons.menu_book_outlined,
                    label: tr('Subject'),
                    value: user.subjectName!,
                  ),
                for (final child in user.children)
                  InfoRow(
                    icon: Icons.child_care_outlined,
                    label: child.firstName,
                    value: child.className ?? '',
                  ),
                InfoRow(
                  icon: Icons.apartment_outlined,
                  label: tr('School'),
                  value: user.schoolName,
                ),
                InfoRow(
                  icon: Icons.alternate_email,
                  label: tr('Email'),
                  value: user.email,
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: tr('Phone'),
                  value: user.phone,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(tr('Edit profile')),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.changePassword),
            icon: const Icon(Icons.lock_reset, size: 20),
            label: Text(tr('Change password')),
          ),
        ],
      ),
    );
  }
}
