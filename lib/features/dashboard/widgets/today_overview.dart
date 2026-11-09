import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../schedule/providers/schedule_provider.dart';
import 'stat_tile.dart';
import '../../../core/l10n/language.dart';

/// Three quick numbers: classes today, work to do, attendance.
class TodayOverview extends ConsumerWidget {
  const TodayOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(todayLessonsProvider).valueOrNull?.length;
    final toDo = ref.watch(pendingAssignmentsProvider).valueOrNull?.length;
    final attendance = ref.watch(attendanceSummaryProvider).valueOrNull?.rate;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.class_outlined,
            color: AppColors.subjectBlue,
            value: classes?.toString() ?? '–',
            label: tr('Classes today'),
            onTap: () => context.go(AppRoutes.schedule),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            icon: Icons.assignment_outlined,
            color: AppColors.warning,
            value: toDo?.toString() ?? '–',
            label: tr('To do'),
            onTap: () => context.go(AppRoutes.work),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            icon: Icons.fact_check_outlined,
            color: AppColors.success,
            value: attendance == null ? '–' : '${attendance.round()}%',
            label: tr('Attendance'),
            onTap: () => context.push(AppRoutes.attendance),
          ),
        ),
      ],
    );
  }
}
