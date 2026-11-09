import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../notifications/providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/l10n/language.dart';

/// Asks before signing out. The router returns to the login page by itself.
Future<void> showSignOutDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Sign out?')),
      content: Text(tr('You will need your ID and password to sign in again.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(tr('Sign out')),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    // First, while still signed in: this phone stops getting their
    // notifications.
    try {
      await ref.read(notificationRepositoryProvider).forgetThisPhone();
    } catch (_) {
      // Offline: the phone's ID was still cancelled with Firebase.
    }
    await ref.read(authProvider.notifier).signOut();
  }
}
