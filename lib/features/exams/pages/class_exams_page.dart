import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/exam_model.dart';
import '../providers/exam_provider.dart';
import '../widgets/exam_sheet.dart';
import '../../../core/l10n/language.dart';

/// A class's exams for the subject's teacher (or every subject for the
/// office): schedule, change, delete, and enter scores after the exam.
class ClassExamsPage extends ConsumerWidget {
  final String classId;

  const ClassExamsPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(classExamsProvider(classId));
    final (className, subjects) = ref.watch(
      classSubjectChoicesProvider(classId),
    );

    void edit([ExamModel? exam]) => showExamSheet(
      context,
      classId: classId,
      subjects: subjects,
      exam: exam,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Exams · {0}', [className]))),
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: Text(tr('Exam')),
            ),
      body: AsyncValueView(
        value: exams,
        onRetry: () => ref.invalidate(classExamsProvider(classId)),
        data: (exams) {
          if (exams.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: tr('No exams yet'),
              message: tr(
                'Schedule a quiz or exam; students and parents see it.',
              ),
            );
          }
          final upcoming = exams.where((e) => !e.canBeScored).toList();
          final past = exams.where((e) => e.canBeScored).toList().reversed;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              96, // room for the button
            ),
            children: [
              if (past.isNotEmpty) ...[
                SectionHeader(title: tr('Done – scores')),
                for (final e in past) ...[
                  _ExamTile(
                    exam: e,
                    onTap: () => context.push(AppRoutes.examScores(e.id)),
                    onEdit: () => edit(e),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              if (upcoming.isNotEmpty) ...[
                SectionHeader(title: tr('Coming up')),
                for (final e in upcoming) ...[
                  _ExamTile(
                    exam: e,
                    onTap: () => edit(e),
                    onEdit: () => edit(e),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ExamTile({
    required this.exam,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final (status, color) = !exam.canBeScored
        ? (tr('In {0} days', [exam.daysLeft]), context.palette.textMuted)
        : exam.published
        ? (tr('{0} scored', [exam.scoredCount]), AppColors.success)
        : (tr('Needs scores'), AppColors.warning);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        0,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconBox(icon: exam.subject.icon, color: exam.subject.color, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.displayTitle, style: context.text.titleSmall),
                Text(
                  '${exam.subject.name} · ${exam.type.label} · '
                  '${DateFormatter.dayMonth(exam.start)} '
                  '${DateFormatter.time(exam.start)}',
                  style: context.text.bodySmall,
                ),
                Text(
                  status,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Edit'),
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
