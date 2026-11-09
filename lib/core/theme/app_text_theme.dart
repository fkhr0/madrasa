import 'package:flutter/material.dart';

import '../l10n/language.dart';

/// Typography. Sizes are modest and line heights generous so long lists
/// stay easy to read for every age group.
class AppTextTheme {
  AppTextTheme._();

  static TextTheme build({
    required Color primaryText,
    required Color secondaryText,
  }) {
    // Cairo reads well in Arabic (and has Latin letters for IDs and names).
    final arabic = AppLanguage.current.isArabic;
    // Both bundled in assets/fonts (see pubspec.yaml).
    final base = ThemeData.light().textTheme.apply(
      fontFamily: arabic ? 'Cairo' : 'PlusJakartaSans',
    );
    // Tight letter spacing breaks joined Arabic letters apart.
    double spacing(double latin) => arabic ? 0 : latin;

    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: spacing(-0.3),
        color: primaryText,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: spacing(-0.2),
        color: primaryText,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: primaryText,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: primaryText,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: primaryText,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: primaryText,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: secondaryText,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondaryText,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: spacing(0.3),
        color: secondaryText,
      ),
    );
  }
}
