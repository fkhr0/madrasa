import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../utils/context_extensions.dart';
import 'icon_box.dart';

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// A row of big coloured shortcuts (used on every home page).
class QuickActionsRow extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final action in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    IconBox(icon: action.icon, color: action.color, size: 52),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      action.label,
                      style: context.text.labelMedium?.copyWith(
                        color: context.palette.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
