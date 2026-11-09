import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import '../widgets/attachment_tile.dart';
import '../../../core/l10n/language.dart';

/// Who handed in one piece of work. Tap a student to grade them (also
/// work handed in on paper); they and their parents are told.
class SubmissionsPage extends ConsumerWidget {
  final String assignmentId;

  const SubmissionsPage({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(submissionsProvider(assignmentId));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Hand-ins'))),
      body: AsyncValueView(
        value: sheet,
        onRetry: () => ref.invalidate(submissionsProvider(assignmentId)),
        data: (sheet) {
          final (assignment, students) = sheet;
          final handedIn = students.where((s) => s.handedIn).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(assignment.title, style: context.text.titleMedium),
              Text(
                tr('{0} · {1} · due {2} · out of {3}', [
                  assignment.subject.name,
                  assignment.className,
                  DateFormatter.relativeDay(assignment.dueDate),
                  assignment.maxGrade!.round(),
                ]),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('{0} of {1} handed in', [handedIn, students.length]),
                style: context.text.labelMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final s in students) ...[
                _StudentCard(
                  assignment: assignment,
                  student: s,
                  onTap: () => _grade(context, ref, assignment, s),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _grade(
    BuildContext context,
    WidgetRef ref,
    AssignmentModel assignment,
    StudentSubmissionModel student,
  ) async {
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _GradeDialog(assignment: assignment, student: student),
    );
    if (result == null) return;

    try {
      await ref
          .read(assignmentActionsProvider)
          .grade(assignment, student.id, grade: result.$1, feedback: result.$2);
      if (context.mounted) {
        context.showMessage(tr('{0} graded', [student.name]));
      }
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }
}

class _StudentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final StudentSubmissionModel student;
  final VoidCallback onTap;

  const _StudentCard({
    required this.assignment,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final submittedAt = student.submittedAt;
    final late = submittedAt != null && submittedAt.isAfter(assignment.dueDate);
    final grade = student.grade;
    final percent = grade == null ? null : grade / assignment.maxGrade! * 100;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: student.name, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: context.text.titleSmall),
                    Text(
                      submittedAt == null
                          ? tr('Not handed in')
                          : tr('Handed in {0} {1}{2}', [
                              DateFormatter.relativeDay(
                                submittedAt,
                              ).toLowerCase(),
                              DateFormatter.time(submittedAt),
                              late ? tr(' · late') : '',
                            ]),
                      style: context.text.bodySmall?.copyWith(
                        color: submittedAt == null
                            ? context.palette.textMuted
                            : late
                            ? AppColors.warning
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (grade != null && percent != null)
                Text(
                  '${_plain(grade)} / ${_plain(assignment.maxGrade!)}',
                  style: context.text.titleMedium?.copyWith(
                    color: GradeScale.colorFor(percent),
                  ),
                )
              else
                Text(
                  tr('Grade'),
                  style: context.text.labelMedium?.copyWith(
                    color: context.palette.primary,
                  ),
                ),
            ],
          ),
          for (final file in student.files) ...[
            const SizedBox(height: AppSpacing.sm),
            AttachmentTile(attachment: file),
          ],
          if (student.feedback case final feedback?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('“$feedback”', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

String _plain(double n) =>
    n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

class _GradeDialog extends StatefulWidget {
  final AssignmentModel assignment;
  final StudentSubmissionModel student;

  const _GradeDialog({required this.assignment, required this.student});

  @override
  State<_GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<_GradeDialog> {
  late final _grade = TextEditingController(
    text: widget.student.grade == null ? '' : _plain(widget.student.grade!),
  );
  late final _feedback = TextEditingController(text: widget.student.feedback);
  String? _error;

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _done() {
    final max = widget.assignment.maxGrade!;
    final grade = double.tryParse(_grade.text.trim());
    if (grade == null || grade < 0 || grade > max) {
      setState(() => _error = tr('Between 0 and {0}', [_plain(max)]));
      return;
    }
    Navigator.pop(context, (grade, _feedback.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.student.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _grade,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: tr('Grade out of {0}', [
                _plain(widget.assignment.maxGrade!),
              ]),
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _feedback,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr('Feedback (optional)')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(onPressed: _done, child: Text(tr('Save grade'))),
      ],
    );
  }
}
