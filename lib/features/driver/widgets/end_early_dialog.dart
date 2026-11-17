import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

Future<String?> showEndEarlyDialog(BuildContext context) {
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
