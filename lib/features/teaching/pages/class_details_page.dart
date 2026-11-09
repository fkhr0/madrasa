import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../providers/teaching_provider.dart';
import '../widgets/student_row.dart';
import '../../../core/l10n/language.dart';

class ClassDetailsPage extends ConsumerWidget {
  final String classId;

  const ClassDetailsPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachingClass = ref.watch(classByIdProvider(classId)).valueOrNull;
    final students = ref.watch(classStudentsProvider(classId));

    return Scaffold(
      appBar: AppBar(title: Text(teachingClass?.name ?? '')),
      body: AsyncValueView(
        value: students,
        onRetry: () => ref.invalidate(classStudentsProvider(classId)),
        data: (students) {
          if (students.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: tr('No students in this class'),
            );
          }

          // Only students with grades count (none before the first test).
          final graded = [for (final s in students) ?s.average];
          final average = graded.isEmpty
              ? null
              : graded.reduce((a, b) => a + b) / graded.length;
          final belowPass = graded.where((a) => a < GradeScale.passMark).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              // ---------- Summary ----------
              AppCard(
                child: Row(
                  children: [
                    _Figure(
                      value: average == null ? '–' : '${average.round()}',
                      label: tr('Class average'),
                      color: average == null
                          ? context.palette.textMuted
                          : GradeScale.colorFor(average),
                    ),
                    _Figure(
                      value: '${students.length}',
                      label: tr('Students'),
                      color: context.palette.textPrimary,
                    ),
                    _Figure(
                      value: '$belowPass',
                      label: tr('Below 50'),
                      color: belowPass > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---------- Actions ----------
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.takeAttendance(classId)),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(tr('Attendance')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.classExams(classId)),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text(tr('Exams & grades')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.classAssignments(classId)),
                icon: const Icon(Icons.assignment_outlined, size: 18),
                label: Text(tr('Homework & hand-ins')),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.classResources(classId)),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(tr('Study material')),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---------- Students ----------
              SectionHeader(title: tr('Students')),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < students.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                        ),
                      StudentRow(student: students[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Figure({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: context.text.headlineSmall?.copyWith(color: color),
          ),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}
