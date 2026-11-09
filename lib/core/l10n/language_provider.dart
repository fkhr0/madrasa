import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language.dart';

const _key = 'language';

/// The language saved on this device (Arabic the first time).
Future<AppLanguage> loadSavedLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return AppLanguage.values.where((l) => l.name == saved).firstOrNull ??
        AppLanguage.ar;
  } catch (_) {
    return AppLanguage.ar;
  }
}

/// The app's language. Changing it rebuilds the whole app in the other
/// language and direction, and remembers the choice on this device.
final languageProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);

class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.current;

  Future<void> set(AppLanguage language) async {
    AppLanguage.current = language;
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.name);
    } catch (_) {
      // Not saved (private browser window): it still applies until closed.
    }
  }
}
