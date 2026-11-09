import 'package:flutter/material.dart';

/// Shadows are used lightly: cards get a soft lift in light mode only
/// (dark mode relies on borders, shadows don't show there).
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D1C2033), // textPrimary at ~5%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x081C2033), blurRadius: 2, offset: Offset(0, 1)),
  ];
}
