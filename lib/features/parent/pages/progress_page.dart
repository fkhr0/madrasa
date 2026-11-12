import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../assignments/widgets/assignment_tile.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/widgets/attendance_summary_card.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../grades/providers/grade_provider.dart';
import '../../grades/widgets/overall_average_card.dart';
import '../../grades/widgets/subject_grades_card.dart';
import '../../grades/widgets/year_result_card.dart';
import '../widgets/child_switcher.dart';
import '../../../core/l10n/language.dart';

/// Parent's third tab: grades, attendance and pending work in one place.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeStudentProvider);
    final grades = ref.watch(gradesProvider);
    final average = ref.watch(overallAverageProvider).valueOrNull;
    final attendance = ref.watch(attendanceSummaryProvider).valueOrNull;
    final pending = ref.watch(pendingAssignmentsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          child == null
              ? tr('Progress')
              : tr('{0}\'s progress', [child.firstName]),
        ),
      ),
      body: AsyncValueView(
        value: grades,
        onRetry: () => ref.invalidate(gradesProvider),
        data: (subjects) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            const ChildSwitcher(),
            const SizedBox(height: AppSpacing.lg),
            OverallAverageCard(
              average: average,
              subjectCount: subjects.where((s) => s.hasMarks).length,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (attendance != null) ...[
              SectionHeader(
                title: tr('Attendance'),
                onSeeAll: () => context.push(AppRoutes.attendance),
              ),
              AttendanceSummaryCard(summary: attendance),
              const SizedBox(height: AppSpacing.xl),
            ],

            SectionHeader(title: tr('Year result')),
            YearResultCard(
              results: ref.watch(yearResultsProvider).valueOrNull ?? const [],
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: tr('Subjects')),
            for (final subject in subjects) ...[
              SubjectGradesCard(grades: subject),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.md),

            if (pending.isNotEmpty) ...[
              SectionHeader(title: tr('Work to do')),
              for (final assignment in pending) ...[
                AssignmentTile(assignment: assignment),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
