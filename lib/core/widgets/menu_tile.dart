import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';
import 'icon_box.dart';

/// One row of a menu list (More page, Settings page).
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Colours the icon and the title (e.g. red for "Sign out").
  final Color? color;

  /// Colours only the icon. Falls back to [color], then the primary colour.
  final Color? iconColor;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            IconBox(
              icon: icon,
              color: iconColor ?? color ?? palette.primary,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(color: color),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(Icons.chevron_right, color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}
