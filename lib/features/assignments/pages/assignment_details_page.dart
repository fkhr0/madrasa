import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/widgets/reminder_sheet.dart';
import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import '../widgets/attachment_tile.dart';
import '../widgets/grade_section.dart';
import '../widgets/submission_section.dart';
import '../../../core/l10n/language.dart';

class AssignmentDetailsPage extends ConsumerWidget {
  final String assignmentId;

  const AssignmentDetailsPage({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignment = ref.watch(assignmentByIdProvider(assignmentId));
    final loaded = assignment.valueOrNull;
    final isStudent = ref.watch(currentUserProvider).role == UserRole.student;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (isStudent &&
              loaded != null &&
              loaded.status == AssignmentStatus.pending)
            IconButton(
              tooltip: tr('Remind me'),
              onPressed: () => showReminderSheet(
                context,
                title: tr('Work on "{0}"', [loaded.title]),
                before: loaded.dueDate,
                route: AppRoutes.assignmentDetails(loaded.id),
              ),
              icon: const Icon(Icons.alarm_add),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AsyncValueView(
        value: assignment,
        data: (assignment) {
          if (assignment == null) {
            return EmptyState(
              icon: Icons.search_off,
              title: tr('Assignment not found'),
            );
          }

          final isStudent =
              ref.watch(currentUserProvider).role == UserRole.student;

          return _Content(assignment: assignment, canSubmit: isStudent);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final AssignmentModel assignment;
  final bool canSubmit;

  const _Content({required this.assignment, required this.canSubmit});

  @override
  Widget build(BuildContext context) {
    final subject = assignment.subject;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        // ---------- Header ----------
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusBadge(
              label: subject.name,
              color: subject.color,
              icon: subject.icon,
            ),
            if (assignment.isOverdue)
              StatusBadge(label: tr('Late'), color: AppColors.danger)
            else
              StatusBadge(
                label: assignment.status.label,
                color: assignment.status.color,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(assignment.title, style: context.text.headlineSmall),
        const SizedBox(height: AppSpacing.lg),

        // ---------- Key facts ----------
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.event_outlined,
                label: tr('Due'),
                value:
                    '${DateFormatter.relativeDay(assignment.dueDate)}, '
                    '${DateFormatter.time(assignment.dueDate)}',
              ),
              InfoRow(
                icon: Icons.category_outlined,
                label: tr('Type'),
                value: assignment.type.label,
              ),
              InfoRow(
                icon: Icons.person_outline,
                label: tr('Teacher'),
                value: subject.teacherName,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---------- Instructions ----------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Instructions'), style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(assignment.description, style: context.text.bodyLarge),
              for (final file in assignment.attachments) ...[
                const SizedBox(height: AppSpacing.sm),
                AttachmentTile(attachment: file),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---------- Grade (when graded) ----------
        if (assignment.status == AssignmentStatus.graded &&
            assignment.grade != null) ...[
          GradeSection(assignment: assignment),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ---------- Submission ----------
        if (assignment.type != AssignmentType.quiz)
          SubmissionSection(assignment: assignment, canSubmit: canSubmit),
      ],
    );
  }
}
