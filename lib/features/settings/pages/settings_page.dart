import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../auth/widgets/sign_out_dialog.dart';
import '../widgets/account_actions.dart';
import '../widgets/notification_settings_group.dart';
import '../widgets/theme_selector.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/language_provider.dart';

class SettingsPage extends ConsumerWidget {
  /// العربية or English. The app rebuilds in the chosen language at once.
  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(languageProvider);
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              ListTile(
                title: Text(language.nativeName),
                trailing: language == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheet, language),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await ref.read(languageProvider.notifier).set(picked);
    }
  }

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          const ThemeSelector(),
          const SizedBox(height: AppSpacing.xl),

          const NotificationSettingsGroup(),
          const SizedBox(height: AppSpacing.xl),

          MenuGroup(
            title: tr('General'),
            children: [
              MenuTile(
                icon: Icons.language,
                title: tr('Language'),
                subtitle: ref.watch(languageProvider).nativeName,
                onTap: () => _chooseLanguage(context, ref),
              ),
              MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: tr('Privacy policy'),
                onTap: () => openAccountPage(ref, '/privacy'),
              ),
              MenuTile(
                icon: Icons.info_outline,
                title: tr('Version'),
                trailing: Text('1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.devices_outlined,
                title: tr('Sign out of all devices'),
                onTap: () => signOutEverywhere(context, ref),
              ),
              MenuTile(
                icon: Icons.person_remove_outlined,
                title: tr('Delete my account'),
                color: AppColors.danger,
                onTap: () => askToDeleteAccount(context, ref),
              ),
              MenuTile(
                icon: Icons.logout,
                title: tr('Sign out'),
                color: AppColors.danger,
                trailing: const SizedBox.shrink(),
                onTap: () => showSignOutDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
