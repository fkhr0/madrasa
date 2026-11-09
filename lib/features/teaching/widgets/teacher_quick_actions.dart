import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_actions_row.dart';
import 'class_picker_sheet.dart';
import '../../../core/l10n/language.dart';

/// The things a teacher does most: attendance, homework, grades and
/// announcements. The first three ask "which class?" first.
class TeacherQuickActions extends StatelessWidget {
  const TeacherQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickActionsRow(
      actions: [
        QuickAction(
          icon: Icons.fact_check_outlined,
          label: tr('Attendance'),
          color: AppColors.success,
          onTap: () => showClassPicker(
            context,
            title: tr('Take attendance for…'),
            routeFor: AppRoutes.takeAttendance,
          ),
        ),
        QuickAction(
          icon: Icons.add_task,
          label: tr('Assignment'),
          color: AppColors.subjectBlue,
          onTap: () => showClassPicker(
            context,
            title: tr('New assignment for…'),
            routeFor: AppRoutes.newAssignment,
          ),
        ),
        QuickAction(
          icon: Icons.edit_note,
          label: tr('Grades'),
          color: AppColors.warning,
          onTap: () => showClassPicker(
            context,
            title: tr('Exams and grades for…'),
            routeFor: AppRoutes.classExams,
          ),
        ),
        QuickAction(
          icon: Icons.campaign_outlined,
          label: tr('Announce'),
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.newAnnouncement),
        ),
      ],
    );
  }
}
