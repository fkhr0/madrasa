import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'context_extensions.dart';
import '../l10n/language.dart';

/// Opens the phone's dialer with [phone] ("+964 770 123 4567").
Future<void> callPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) {
    context.showMessage(tr('No phone number on file'));
    return;
  }

  final opened = await launchUrl(Uri(scheme: 'tel', path: number));
  if (!opened && context.mounted) {
    context.showMessage(tr('Call {0} from your phone', [phone]));
  }
}
