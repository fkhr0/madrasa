import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_actions_row.dart';
import '../../tasks/widgets/reminder_sheet.dart';
import '../../../core/l10n/language.dart';

/// Shortcuts to the places students open most.
class QuickAccessRow extends StatelessWidget {
  const QuickAccessRow({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickActionsRow(
      actions: [
        QuickAction(
          icon: Icons.auto_awesome_outlined,
          label: tr('My plan'),
          color: AppColors.subjectPink,
          onTap: () => context.push(AppRoutes.planner),
        ),
        QuickAction(
          icon: Icons.quiz_outlined,
          label: tr('Exams'),
          color: AppColors.danger,
          onTap: () => context.push(AppRoutes.exams),
        ),
        QuickAction(
          icon: Icons.grade_outlined,
          label: tr('Grades'),
          color: AppColors.success,
          onTap: () => context.push(AppRoutes.grades),
        ),
        QuickAction(
          icon: Icons.calendar_month_outlined,
          label: tr('Calendar'),
          color: AppColors.subjectBlue,
          onTap: () => context.push(AppRoutes.calendar),
        ),
        QuickAction(
          icon: Icons.alarm_add,
          label: tr('Remind me'),
          color: AppColors.warning,
          onTap: () => showReminderSheet(context),
        ),
      ],
    );
  }
}
