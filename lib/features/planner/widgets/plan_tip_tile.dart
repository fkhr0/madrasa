import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../tasks/widgets/reminder_sheet.dart';
import '../models/plan_tip_model.dart';
import '../../../core/l10n/language.dart';

class PlanTipTile extends StatelessWidget {
  final PlanTipModel tip;

  /// Shows a "Remind me" button (for students).
  final bool canRemind;

  const PlanTipTile({super.key, required this.tip, this.canRemind = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: tip.route == null ? null : () => context.push(tip.route!),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBox(icon: tip.icon, color: tip.color, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: context.text.titleSmall),
                if (tip.detail != null)
                  Text(
                    tip.detail!,
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (canRemind)
            IconButton(
              tooltip: tr('Remind me'),
              onPressed: () => showReminderSheet(
                context,
                title: tip.title,
                route: tip.route,
              ),
              icon: Icon(Icons.alarm_add, color: context.palette.textMuted),
            )
          else if (tip.route != null)
            Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
