import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';

/// The base surface of the app: rounded, a hairline border, and a soft
/// shadow in light mode so cards lift off the background.
/// Pass [onTap] to make the whole card tappable.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.lg);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Tinted cards (custom colour) stay flat; plain cards get the shadow.
    final lifted = isLight && color == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: lifted ? AppShadows.card : null,
      ),
      child: Material(
        color: color ?? palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color:
                borderColor ??
                (lifted
                    ? palette.border.withValues(alpha: 0.6)
                    : palette.border),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
