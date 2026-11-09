import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../files/providers/file_provider.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';
import '../providers/assignment_provider.dart';
import 'attachment_tile.dart';
import '../../../core/l10n/language.dart';

/// "Your work" card: pick files and hand them in, or see what was handed in.
class SubmissionSection extends ConsumerStatefulWidget {
  final AssignmentModel assignment;

  /// False for parents: they can see the work but not hand it in.
  final bool canSubmit;

  const SubmissionSection({
    super.key,
    required this.assignment,
    this.canSubmit = true,
  });

  @override
  ConsumerState<SubmissionSection> createState() => _SubmissionSectionState();
}

class _SubmissionSectionState extends ConsumerState<SubmissionSection> {
  final List<AttachmentModel> _picked = [];
  bool _isSubmitting = false;
  bool _isUploading = false;

  Future<void> _addFiles() async {
    setState(() => _isUploading = true);
    final files = await pickAndUpload(context, ref);
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _picked.addAll(files);
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(assignmentActionsProvider)
          .submit(widget.assignment.id, _picked);
      if (!mounted) return;
      context.showMessage(tr('Your work was handed in.'));
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.canSubmit ? tr('Your work') : tr('Handed-in work'),
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (assignment.status == AssignmentStatus.pending &&
              !widget.canSubmit)
            Text(tr('Not handed in yet.'), style: context.text.bodyMedium)
          else if (assignment.status == AssignmentStatus.pending)
            ..._buildPicker(context, assignment)
          else
            ..._buildSubmitted(context, assignment),
        ],
      ),
    );
  }

  List<Widget> _buildPicker(BuildContext context, AssignmentModel assignment) {
    if (!assignment.canSubmit) {
      return [
        Text(
          tr(
            'The due date has passed and late work is not accepted. Please talk to your teacher.',
          ),
          style: context.text.bodyMedium,
        ),
      ];
    }

    return [
      if (assignment.isOverdue)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            tr('This is past the due date. It will be marked as late.'),
            style: context.text.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ),
      for (final file in _picked)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AttachmentTile(
            attachment: file,
            onRemove: () async {
              final sure = await confirmDelete(
                context,
                title: tr('Remove {0}?', [file.name]),
                action: tr('Remove'),
              );
              if (sure) setState(() => _picked.remove(file));
            },
          ),
        ),
      if (assignment.acceptsFiles) ...[
        OutlinedButton.icon(
          onPressed: _isSubmitting || _isUploading ? null : _addFiles,
          icon: _isUploading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file, size: 20),
          label: Text(_isUploading ? tr('Uploading…') : tr('Add file')),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      FilledButton(
        onPressed:
            (assignment.acceptsFiles && _picked.isEmpty) ||
                _isSubmitting ||
                _isUploading
            ? null
            : _submit,
        child: _isSubmitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                assignment.acceptsFiles ? tr('Hand in') : tr('Mark as done'),
              ),
      ),
    ];
  }

  List<Widget> _buildSubmitted(
    BuildContext context,
    AssignmentModel assignment,
  ) {
    return [
      Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              assignment.submittedAt == null
                  ? tr('Handed in')
                  : tr('Handed in {0} at {1}', [
                      DateFormatter.relativeDay(
                        assignment.submittedAt!,
                      ).toLowerCase(),
                      DateFormatter.time(assignment.submittedAt!),
                    ]),
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
      for (final file in assignment.submittedFiles) ...[
        const SizedBox(height: AppSpacing.sm),
        AttachmentTile(attachment: file),
      ],
    ];
  }
}
