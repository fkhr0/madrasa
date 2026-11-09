import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';
import 'app_card.dart';

/// A titled card that stacks MenuTiles with thin dividers between them.
class MenuGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const MenuGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
