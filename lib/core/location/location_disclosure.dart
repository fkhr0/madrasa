import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/language.dart';

/// Google Play's "prominent disclosure": before the phone asks for location,
/// the driver reads what is collected, why, and that it goes on with the app
/// closed.
Future<bool> confirmBusLocationSharing(BuildContext context) async {
  if (kIsWeb) return true;
  const key = 'bus_location_disclosure_accepted';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) ?? false) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.share_location_outlined),
      title: Text(tr('Sharing the bus location')),
      content: Text(
        tr(
          'Madrasa collects this phone\'s location to show the school bus to '
          'students\' families on a map during a trip, even when the app is '
          'closed or not in use. Sharing stops when you end the trip. The '
          'location is not used for anything else and is not sold.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Not now')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('Continue')),
        ),
      ],
    ),
  );
  if (accepted == true) await prefs.setBool(key, true);
  return accepted == true;
}
