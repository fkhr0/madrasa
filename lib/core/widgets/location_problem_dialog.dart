import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../location/device_location.dart';

/// Why the location can't be read, with a button to the setting that fixes
/// it. A dialog, not a snackbar: it shows above bottom sheets too.
Future<void> showLocationProblem(BuildContext context, LocationException e) {
  final action = switch (e.fix) {
    LocationFix.turnOn => tr('Turn on location'),
    LocationFix.allow => tr('Open settings'),
    LocationFix.none => null,
  };
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_off_outlined),
      title: Text(tr('Location is needed')),
      content: Text(e.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(action == null ? tr('OK') : tr('Not now')),
        ),
        if (action != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              DeviceLocation.openSettingsFor(e.fix);
            },
            child: Text(action),
          ),
      ],
    ),
  );
}
