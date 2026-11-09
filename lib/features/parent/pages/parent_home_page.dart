import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../dashboard/widgets/greeting_header.dart';
import '../../dashboard/widgets/latest_announcements_section.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../grades/providers/grade_provider.dart';
import '../../planner/widgets/for_you_section.dart';
import '../../today/widgets/day_status_card.dart';
import '../../transport/widgets/bus_mini_card.dart';
import '../widgets/child_switcher.dart';
import '../../../core/l10n/language.dart';

/// Parent's 10–30 second screen: where my child is in their day,
/// how they're doing, and what deserves my attention.
class ParentHomePage extends ConsumerWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeStudentProvider);
    final average = ref.watch(overallAverageProvider).valueOrNull;
    final attendance = ref.watch(attendanceSummaryProvider).valueOrNull?.rate;
    final pending = ref.watch(pendingAssignmentsProvider).valueOrNull?.length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            const GreetingHeader(),
            const SizedBox(height: AppSpacing.lg),
            const ChildSwitcher(),
            const SizedBox(height: AppSpacing.lg),
            DayStatusCard(who: child?.firstName),
            const SizedBox(height: AppSpacing.md),
            const BusMiniCard(),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.grade_outlined,
                    color: AppColors.success,
                    value: average == null ? '–' : '${average.round()}',
                    label: tr('Average'),
                    onTap: () => context.go(AppRoutes.work),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.fact_check_outlined,
                    color: AppColors.subjectTeal,
                    value: attendance == null ? '–' : '${attendance.round()}%',
                    label: tr('Attendance'),
                    onTap: () => context.push(AppRoutes.attendance),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.assignment_outlined,
                    color: AppColors.warning,
                    value: pending?.toString() ?? '–',
                    label: tr('Work to do'),
                    onTap: () => context.go(AppRoutes.work),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const ForYouSection(),
            const SizedBox(height: AppSpacing.lg),
            const LatestAnnouncementsSection(),
          ],
        ),
      ),
    );
  }
}
