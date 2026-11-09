import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';

/// A page on the server's website, e.g. the privacy policy, in the browser.
Future<void> openAccountPage(WidgetRef ref, String path) async {
  if (!AppConfig.useApi) return;
  await launchUrl(
    ref.read(apiClientProvider).resolve(path),
    mode: LaunchMode.externalApplication,
  );
}

/// Every other phone and computer is signed out; this one stays in.
Future<void> signOutEverywhere(BuildContext context, WidgetRef ref) async {
  final sure = await confirmDelete(
    context,
    title: tr('Sign out of all other devices?'),
    message: tr('This phone stays signed in.'),
    action: tr('Sign out'),
  );
  if (!sure || !AppConfig.useApi) return;
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/me/sign-out-everywhere', {
      'refreshToken': api.refreshToken,
    });
    if (context.mounted) {
      context.showMessage(tr('Signed out of all other devices'));
    }
  } on ApiException catch (e) {
    if (context.mounted) context.showMessage(e.message);
  }
}

/// Accounts belong to the school: this asks the office to delete it (and
/// says what that means). Google Play requires the way to ask.
Future<void> askToDeleteAccount(BuildContext context, WidgetRef ref) async {
  final reason = TextEditingController();
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Delete my account')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'Your school office is asked to delete your account within 30 days. '
              'You will no longer be able to sign in. The school may keep records '
              'it is required to keep.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLength: 500,
            decoration: InputDecoration(labelText: tr('Why? (optional)')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(tr('Ask to delete')),
        ),
      ],
    ),
  );
  final text = reason.text.trim();
  reason.dispose();
  if (sure != true || !AppConfig.useApi) return;
  try {
    await ref.read(apiClientProvider).post('/me/deletion-request', {
      if (text.isNotEmpty) 'reason': text,
    });
    if (context.mounted) {
      context.showMessage(
        tr('Your school office was asked to delete your account'),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) context.showMessage(e.message);
  }
}
