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
import '../../teaching/providers/teaching_provider.dart';
import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import '../../../core/l10n/language.dart';

/// A class's homework for the subject's teacher (every subject for the
/// office): tap to see hand-ins and grade, pencil to change.
class ClassAssignmentsPage extends ConsumerWidget {
  final String classId;

  const ClassAssignmentsPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final work = ref.watch(classAssignmentsProvider(classId));
    final (className, subjects) = ref.watch(
      classSubjectChoicesProvider(classId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Homework · {0}', [className]))),
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.newAssignment(classId)),
              icon: const Icon(Icons.add),
              label: Text(tr('Work')),
            ),
      body: AsyncValueView(
        value: work,
        onRetry: () => ref.invalidate(classAssignmentsProvider(classId)),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.assignment_outlined,
                title: tr('No homework yet'),
                message: tr('Set work; students and parents see it at once.'),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  96, // room for the button
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _WorkTile(
                  assignment: items[i],
                  onTap: () => context.push(AppRoutes.submissions(items[i].id)),
                  onEdit: () => context.push(
                    AppRoutes.editAssignment(classId, items[i].id),
                  ),
                ),
              ),
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _WorkTile({
    required this.assignment,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = assignment.submittedCount - assignment.gradedCount;

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
          IconBox(
            icon: assignment.subject.icon,
            color: assignment.subject.color,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title, style: context.text.titleSmall),
                Text(
                  tr('{0} · {1} · due {2}', [
                    assignment.subject.name,
                    assignment.type.label,
                    DateFormatter.dayMonth(assignment.dueDate),
                  ]),
                  style: context.text.bodySmall,
                ),
                Text(
                  tr('{0} handed in · {1} graded', [
                    assignment.submittedCount,
                    assignment.gradedCount,
                  ]),
                  style: context.text.labelSmall?.copyWith(
                    color: waiting > 0 ? AppColors.warning : null,
                  ),
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
