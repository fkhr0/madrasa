import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/config/server_address.dart';
import 'core/l10n/language.dart';
import 'core/l10n/language_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/push/phone_push.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLanguage.current = await loadSavedLanguage();
  await ServerAddress.load();
  addFontLicenses();
  await PhonePush.start();
  final container = ProviderContainer();
  await container.read(authProvider.notifier).restore();
  runApp(
    UncontrolledProviderScope(container: container, child: const SchoolApp()),
  );
}

void addFontLicenses() {
  for (final (font, file) in [
    ('Cairo', 'OFL-Cairo.txt'),
    ('Plus Jakarta Sans', 'OFL-PlusJakartaSans.txt'),
  ]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$file'));
    });
  }
}

class SchoolApp extends ConsumerWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return MaterialApp.router(
      key: ValueKey(language),
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
