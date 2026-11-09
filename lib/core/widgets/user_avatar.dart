import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../theme/app_colors.dart';

/// Circle with the person's initials. Each name always gets the same
/// muted colour, so people are easy to recognise in lists.
/// (Profile pictures replace the initials once the backend is connected.)
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = AppSizes.avatarSm,
  });

  static const _colors = [
    AppColors.subjectBlue,
    AppColors.subjectGreen,
    AppColors.subjectOrange,
    AppColors.subjectPurple,
    AppColors.subjectAmber,
    AppColors.subjectTeal,
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();

    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Sum of the letters, so the same name gives the same colour on every run.
    final seed = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
    final color = _colors[seed % _colors.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
