import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_sizes.dart';

/// An icon inside a soft-tinted rounded square.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = AppSizes.iconBox,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
