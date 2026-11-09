import 'counted.dart';
import 'package:flutter/widgets.dart';

import 'arabic.dart';

/// The app's languages. Arabic is the default (Iraqi schools); English can be
/// chosen in Settings.
enum AppLanguage {
  ar('العربية', Locale('ar')),
  en('English', Locale('en'));

  /// The language's own name, for the switch.
  final String nativeName;
  final Locale locale;

  const AppLanguage(this.nativeName, this.locale);

  bool get isArabic => this == ar;

  /// What the app shows now. Set at start-up and when the user switches
  /// (the whole app then rebuilds). English in tests unless they set it.
  static AppLanguage current = en;
}

/// The text in the current language.
String tr(String english, [List<Object?> args = const []]) {
  var text = AppLanguage.current.isArabic
      ? (arabic[english] ?? english)
      : english;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  // "2 أيام" → "يومان", "1 days" → "1 day" (see counted.dart).
  return args.isEmpty
      ? text
      : fixCounts(text, arabic: AppLanguage.current.isArabic);
}
