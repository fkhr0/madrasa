import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../files/providers/file_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/assignment_model.dart';
import '../models/attachment_model.dart';
import '../providers/assignment_provider.dart';
import '../widgets/attachment_tile.dart';
import '../../../core/l10n/language.dart';

/// Teacher or office: set new work for a class, or change / delete
/// [assignmentId].
class AssignmentEditorPage extends ConsumerWidget {
  final String classId;
  final String? assignmentId;

  const AssignmentEditorPage({
    super.key,
    required this.classId,
    this.assignmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = assignmentId;
    if (id == null) {
      return _Editor(classId: classId);
    }

    final list = ref.watch(classAssignmentsProvider(classId));
    return list.when(
      skipLoadingOnReload: true,
      data: (items) => _Editor(
        classId: classId,
        assignment: items.where((a) => a.id == id).firstOrNull,
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  final String classId;
  final AssignmentModel? assignment;

  const _Editor({required this.classId, this.assignment});

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.assignment?.title);
  late final _description = TextEditingController(
    text: widget.assignment?.description,
  );
  late final _maxGrade = TextEditingController(
    text: '${(widget.assignment?.maxGrade ?? 10).round()}',
  );

  late String? _subjectId = widget.assignment?.subject.id;
  late AssignmentType _type =
      widget.assignment?.type ?? AssignmentType.homework;

  /// Default: the next day, at the end of the day.
  late DateTime _dueDate =
      widget.assignment?.dueDate ??
      DateTime.now().copyWith(
        day: DateTime.now().day + 1,
        hour: 23,
        minute: 59,
      );
  late bool _acceptsFiles = widget.assignment?.acceptsFiles ?? true;
  late bool _allowsLate = widget.assignment?.allowsLateSubmission ?? false;
  late final List<AttachmentModel> _attachments = [
    ...?widget.assignment?.attachments,
  ];
  bool _isSaving = false;
  bool _isUploading = false;

  bool get _isNew => widget.assignment == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _maxGrade.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(now) ? now : _dueDate,
      firstDate: _dueDate.isBefore(now) ? _dueDate : now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date != null) {
      setState(() => _dueDate = date.copyWith(hour: 23, minute: 59));
    }
  }

  Future<void> _attach() async {
    setState(() => _isUploading = true);
    final files = await pickAndUpload(context, ref);
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _attachments.addAll(files);
    });
  }

  Future<void> _save(List<(String, String)> subjects) async {
    if (!_formKey.currentState!.validate()) return;
    final subjectId =
        _subjectId ?? (subjects.length == 1 ? subjects.single.$1 : null);
    if (subjectId == null) {
      context.showMessage(tr('Choose the subject'));
      return;
    }

    final draft = AssignmentDraftModel(
      classId: widget.classId,
      subjectId: subjectId,
      title: _title.text.trim(),
      type: _type,
      description: _description.text.trim(),
      dueDate: _dueDate,
      allowsLateSubmission: _allowsLate,
      acceptsFiles: _acceptsFiles,
      maxGrade: double.parse(_maxGrade.text),
      attachments: _attachments,
    );

    setState(() => _isSaving = true);
    try {
      await ref
          .read(assignmentActionsProvider)
          .saveAssignment(draft, assignmentId: widget.assignment?.id);
      if (!mounted) return;
      context.showMessage(
        _isNew ? tr('Published. Students and parents are told.') : tr('Saved'),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _delete() async {
    final assignment = widget.assignment!;
    final sure = await confirmDelete(
      context,
      title: tr('Delete {0}?', [assignment.title]),
      message: assignment.submittedCount > 0
          ? tr('{0} hand-ins and their grades are deleted too.', [
              assignment.submittedCount,
            ])
          : tr('Students no longer see it.'),
    );
    if (!sure || !mounted) return;

    try {
      await ref.read(assignmentActionsProvider).deleteAssignment(assignment);
      if (!mounted) return;
      context.showMessage(tr('{0} deleted', [assignment.title]));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (className, subjects) = ref.watch(
      classSubjectChoicesProvider(widget.classId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? tr('New work · {0}', [className]) : tr('Edit work'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            if (subjects.length > 1) ...[
              Text(tr('Subject'), style: context.text.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (id, name) in subjects)
                    ChoiceChip(
                      label: Text(name),
                      selected: _subjectId == id,
                      onSelected: (_) => setState(() => _subjectId = id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? tr('Add a title') : null,
              decoration: InputDecoration(labelText: tr('Title')),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? tr('Explain what students should do')
                  : null,
              decoration: InputDecoration(
                labelText: tr('Instructions'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(tr('Type'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in AssignmentType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: type == _type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      tr('Due {0}', [DateFormatter.relativeDay(_dueDate)]),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _maxGrade,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                        ? tr('Required')
                        : null,
                    decoration: InputDecoration(labelText: tr('Out of')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Students hand in files')),
              subtitle: Text(tr('Off: they only mark it as done')),
              value: _acceptsFiles,
              onChanged: (v) => setState(() => _acceptsFiles = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Accept late work')),
              subtitle: Text(tr('Handed in after the due date')),
              value: _allowsLate,
              onChanged: (v) => setState(() => _allowsLate = v),
            ),
            const SizedBox(height: AppSpacing.sm),

            for (final file in _attachments)
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
                    if (sure) setState(() => _attachments.remove(file));
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _attach,
              icon: _isUploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file, size: 18),
              label: Text(
                _isUploading ? tr('Uploading…') : tr('Attach a file'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _isSaving || _isUploading
                  ? null
                  : () => _save(subjects),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isNew ? tr('Publish') : tr('Save')),
            ),
            if (!_isNew) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _isSaving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete work')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
