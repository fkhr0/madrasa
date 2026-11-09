import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/greeting_header.dart';
import '../../dashboard/widgets/latest_announcements_section.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../planner/widgets/for_you_section.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../today/widgets/day_status_card.dart';
import '../providers/teaching_provider.dart';
import '../widgets/class_card.dart';
import '../widgets/teacher_quick_actions.dart';
import '../../../core/l10n/language.dart';

/// Teacher's 10–30 second screen: where they are in the teaching day,
/// what needs grading, quick actions and their classes.
class TeacherHomePage extends ConsumerWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(myClassesProvider).valueOrNull ?? [];
    final lessonsToday = ref.watch(todayLessonsProvider).valueOrNull?.length;

    final toGrade = classes.fold(0, (sum, c) => sum + c.toGradeCount);
    final students = classes.fold(0, (sum, c) => sum + c.studentCount);

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
            const SizedBox(height: AppSpacing.xl),
            const DayStatusCard(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.class_outlined,
                    color: AppColors.subjectBlue,
                    value: lessonsToday?.toString() ?? '–',
                    label: tr('Classes today'),
                    onTap: () => context.go(AppRoutes.schedule),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.rate_review_outlined,
                    color: AppColors.warning,
                    value: '$toGrade',
                    label: tr('To grade'),
                    onTap: () => context.go(AppRoutes.work),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.people_outline,
                    color: AppColors.success,
                    value: '$students',
                    label: tr('Students'),
                    onTap: () => context.go(AppRoutes.work),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const TeacherQuickActions(),
            const SizedBox(height: AppSpacing.lg),
            const ForYouSection(),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: tr('My classes'),
              onSeeAll: () => context.go(AppRoutes.work),
            ),
            for (final c in classes) ...[
              ClassCard(teachingClass: c),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            const LatestAnnouncementsSection(),
          ],
        ),
      ),
    );
  }
}
