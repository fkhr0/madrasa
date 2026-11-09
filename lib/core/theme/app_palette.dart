import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The colours a screen needs, with readable names.
/// Read it with `context.palette` (see context_extensions.dart); the right
/// set is picked automatically for light or dark mode.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary;
  final Color onPrimary;

  /// Soft tinted background for highlighted cards and selected items.
  final Color primarySoft;
  final Color onPrimarySoft;

  final Color background;
  final Color card;

  /// Slightly darker card, for nested blocks and input areas.
  final Color cardMuted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;

  /// Two colours for the gradient of the dashboard's hero card.
  final List<Color> hero;

  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.background,
    required this.card,
    required this.cardMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.hero,
  });

  static const light = AppPalette(
    primary: AppColors.lightPrimary,
    onPrimary: Colors.white,
    primarySoft: AppColors.lightPrimarySoft,
    onPrimarySoft: AppColors.lightOnPrimarySoft,
    background: AppColors.lightBackground,
    card: AppColors.lightCard,
    cardMuted: AppColors.lightCardMuted,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    hero: AppColors.lightHero,
  );

  static const dark = AppPalette(
    primary: AppColors.darkPrimary,
    onPrimary: Color(0xFF14183A),
    primarySoft: AppColors.darkPrimarySoft,
    onPrimarySoft: AppColors.darkOnPrimarySoft,
    background: AppColors.darkBackground,
    card: AppColors.darkCard,
    cardMuted: AppColors.darkCardMuted,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    border: AppColors.darkBorder,
    hero: AppColors.darkHero,
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? background,
    Color? card,
    Color? cardMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    List<Color>? hero,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
      background: background ?? this.background,
      card: card ?? this.card,
      cardMuted: cardMuted ?? this.cardMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      hero: hero ?? this.hero,
    );
  }

  // Used by Flutter to animate between light and dark mode.
  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;

    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimarySoft: Color.lerp(onPrimarySoft, other.onPrimarySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardMuted: Color.lerp(cardMuted, other.cardMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      hero: [
        for (var i = 0; i < hero.length; i++)
          Color.lerp(hero[i], other.hero[i], t)!,
      ],
    );
  }
}
