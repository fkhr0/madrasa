import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/sign_out_dialog.dart';
import '../../notifications/providers/notification_provider.dart';
import '../widgets/profile_summary_card.dart';
import '../../../core/l10n/language.dart';

/// Everything that does not fit in the bottom bar. The first groups
/// depend on the role; "Stay informed" and "App" are the same for everyone.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider).role;
    final unread = ref.watch(unreadNotificationsCountProvider);

    MenuTile tile(IconData icon, Color color, String title, String route) =>
        MenuTile(
          icon: icon,
          iconColor: color,
          title: title,
          onTap: () => context.push(route),
        );

    final grades = tile(
      Icons.grade_outlined,
      AppColors.success,
      tr('Grades'),
      AppRoutes.grades,
    );
    final exams = tile(
      Icons.quiz_outlined,
      AppColors.danger,
      tr('Exams'),
      AppRoutes.exams,
    );
    final attendance = tile(
      Icons.fact_check_outlined,
      AppColors.subjectTeal,
      tr('Attendance'),
      AppRoutes.attendance,
    );
    final resources = tile(
      Icons.folder_open_outlined,
      AppColors.subjectOrange,
      tr('Learning resources'),
      AppRoutes.resources,
    );
    final calendar = tile(
      Icons.calendar_month_outlined,
      AppColors.subjectBlue,
      tr('Calendar'),
      AppRoutes.calendar,
    );
    final tasks = tile(
      Icons.checklist,
      AppColors.subjectPurple,
      tr('Tasks and reminders'),
      AppRoutes.tasks,
    );
    final plan = tile(
      Icons.auto_awesome_outlined,
      AppColors.subjectPink,
      tr('My plan'),
      AppRoutes.planner,
    );
    final bus = tile(
      Icons.directions_bus_outlined,
      AppColors.subjectAmber,
      tr('School bus'),
      AppRoutes.bus,
    );

    final roleGroups = switch (role) {
      UserRole.teacher => [
        MenuGroup(title: tr('Teaching'), children: [plan, resources, calendar]),
      ],
      UserRole.parent => [
        MenuGroup(
          title: tr('Your child'),
          children: [
            grades,
            exams,
            attendance,
            bus,
            tile(
              Icons.payments_outlined,
              AppColors.success,
              tr('School fees'),
              AppRoutes.fees,
            ),
            calendar,
          ],
        ),
      ],
      UserRole.admin => [
        MenuGroup(
          title: tr('School'),
          children: [
            tile(
              Icons.tune,
              AppColors.neutral,
              tr('School settings'),
              AppRoutes.schoolSettings,
            ),
            tile(
              Icons.directions_bus_outlined,
              AppColors.subjectAmber,
              tr('Transport'),
              AppRoutes.transport,
            ),
            tile(
              Icons.account_balance_wallet_outlined,
              AppColors.subjectTeal,
              tr('Finance'),
              AppRoutes.finance,
            ),
            tile(
              Icons.insights_outlined,
              AppColors.subjectPurple,
              tr('Statistics'),
              AppRoutes.statistics,
            ),
            calendar,
          ],
        ),
      ],
      UserRole.driver => [
        // Holidays decide the days without trips.
        MenuGroup(title: tr('School days'), children: [calendar]),
      ],
      UserRole.student => [
        MenuGroup(
          title: tr('Academic'),
          children: [grades, exams, attendance, resources],
        ),
        const SizedBox(height: AppSpacing.xl),
        MenuGroup(
          title: tr('Plan your time'),
          children: [plan, calendar, tasks, bus],
        ),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: Text(tr('More'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          const ProfileSummaryCard(),
          const SizedBox(height: AppSpacing.xl),

          ...roleGroups,
          const SizedBox(height: AppSpacing.xl),

          MenuGroup(
            title: tr('Stay informed'),
            children: [
              tile(
                Icons.today_outlined,
                AppColors.success,
                role == UserRole.admin ? tr('School day') : tr('My day'),
                AppRoutes.day,
              ),
              tile(
                Icons.history,
                AppColors.subjectPurple,
                tr('Activity'),
                AppRoutes.activity,
              ),
              tile(
                Icons.campaign_outlined,
                AppColors.info,
                tr('Announcements'),
                AppRoutes.announcements,
              ),
              MenuTile(
                icon: Icons.notifications_none,
                iconColor: AppColors.warning,
                title: tr('Notifications'),
                subtitle: unread > 0 ? tr('{0} unread', [unread]) : null,
                onTap: () => context.push(AppRoutes.notifications),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          MenuGroup(
            title: tr('App'),
            children: [
              tile(
                Icons.settings_outlined,
                AppColors.neutral,
                tr('Settings'),
                AppRoutes.settings,
              ),
              tile(
                Icons.help_outline,
                AppColors.subjectPink,
                tr('Help and support'),
                AppRoutes.help,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          MenuGroup(
            children: [
              MenuTile(
                icon: Icons.logout,
                title: tr('Sign out'),
                color: AppColors.danger,
                trailing: const SizedBox.shrink(),
                onTap: () => showSignOutDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
