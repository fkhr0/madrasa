import 'counted.dart';
import 'package:flutter/widgets.dart';

import 'arabic.dart';

enum AppLanguage {
  ar('العربية', Locale('ar')),
  en('English', Locale('en'));

  final String nativeName;
  final Locale locale;

  const AppLanguage(this.nativeName, this.locale);

  bool get isArabic => this == ar;

  static AppLanguage current = en;
}

String tr(String english, [List<Object?> args = const []]) {
  var text = AppLanguage.current.isArabic
      ? (arabic[english] ?? english)
      : english;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return args.isEmpty
      ? text
      : fixCounts(text, arabic: AppLanguage.current.isArabic);
}
