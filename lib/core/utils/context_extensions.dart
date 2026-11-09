import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../theme/app_palette.dart';

/// Short-hands so widgets can write `context.palette.card`
/// instead of `Theme.of(context).extension<AppPalette>()!.card`.
extension ContextExtensions on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  TextTheme get text => Theme.of(this).textTheme;

  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      // tr() here too: a message already translated (or from the server,
      // already in the person's language) comes back unchanged.
      ..showSnackBar(SnackBar(content: Text(tr(message))));
  }
}
