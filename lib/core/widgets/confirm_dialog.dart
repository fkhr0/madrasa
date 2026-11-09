import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../l10n/language.dart';

/// Asks before anything is deleted or removed. Every delete in the app
/// goes through this, so nothing disappears by one wrong tap.
/// Returns true only when the user pressed the red button.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
  String? action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action ?? tr('Delete')),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
