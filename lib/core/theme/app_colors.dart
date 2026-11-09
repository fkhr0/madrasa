import 'package:flutter/material.dart';

/// Raw colour values.
class AppColors {
  AppColors._();

  // ---------- Light mode ----------
  static const Color lightPrimary = Color(0xFF4C5FD5);
  static const Color lightPrimarySoft = Color(0xFFE9ECFC);
  static const Color lightOnPrimarySoft = Color(0xFF26318A);
  static const Color lightBackground = Color(0xFFF5F6FB);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardMuted = Color(0xFFEEF0F7);
  static const Color lightTextPrimary = Color(0xFF1C2033);
  static const Color lightTextSecondary = Color(0xFF5B6178);
  static const Color lightTextMuted = Color(0xFF8D93A8);
  static const Color lightBorder = Color(0xFFE4E7F0);

  // ---------- Dark mode ----------
  static const Color darkPrimary = Color(0xFF8E9BFF);
  static const Color darkPrimarySoft = Color(0xFF2C3266);
  static const Color darkOnPrimarySoft = Color(0xFFDDE1FF);
  static const Color darkBackground = Color(0xFF12141F);
  static const Color darkCard = Color(0xFF1B1E2C);
  static const Color darkCardMuted = Color(0xFF252938);
  static const Color darkTextPrimary = Color(0xFFECEEF6);
  static const Color darkTextSecondary = Color(0xFFA6ABC2);
  static const Color darkTextMuted = Color(0xFF737992);
  static const Color darkBorder = Color(0xFF2C3042);

  // ---------- Hero gradient (the "next class" card) ----------
  static const List<Color> lightHero = [Color(0xFF4C5FD5), Color(0xFF7A5AD8)];
  static const List<Color> darkHero = [Color(0xFF3A47A8), Color(0xFF5A3FA6)];

  // ---------- Status (same in both modes) ----------
  static const Color success = Color(0xFF2FA67A);
  static const Color warning = Color(0xFFE0922B);
  static const Color danger = Color(0xFFE05A5A);
  static const Color info = Color(0xFF3B8FD9);
  static const Color neutral = Color(0xFF8D93A8);

  /// Warm highlight for small moments (streaks, "today" markers).
  static const Color accent = Color(0xFFF2845C);

  // ---------- Subject accents ----------
  // Clear but softened tones, readable on white and on dark cards.
  static const Color subjectBlue = Color(0xFF4C7EF3);
  static const Color subjectTeal = Color(0xFF14A3A3);
  static const Color subjectGreen = Color(0xFF3BAA6B);
  static const Color subjectOrange = Color(0xFFF08A4B);
  static const Color subjectPurple = Color(0xFF8B6CE0);
  static const Color subjectPink = Color(0xFFE26D9B);
  static const Color subjectAmber = Color(0xFFD9A12B);
}
