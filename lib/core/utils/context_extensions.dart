import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../theme/app_palette.dart';

extension ContextExtensions on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  TextTheme get text => Theme.of(this).textTheme;

  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(message))));
  }
}
