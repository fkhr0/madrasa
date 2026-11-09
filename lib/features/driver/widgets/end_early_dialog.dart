import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

/// Asks why the trip is ending before the last stop.
/// Returns the reason, or null when the driver changes their mind.
Future<String?> showEndEarlyDialog(BuildContext context) {
  // Sent in English: the server tells each family in their app's language.
  const reasons = [
    'Bus broke down',
    'Road closed',
    'Accident',
    'Told by the school',
  ];

  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(tr('End the trip early?')),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            tr(
              'Families on this line and the school office are told. Pick the reason:',
            ),
          ),
        ),
        for (final reason in reasons)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, reason),
            child: Text(tr(reason)),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Keep driving')),
        ),
      ],
    ),
  );
}
