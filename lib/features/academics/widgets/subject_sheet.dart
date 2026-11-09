import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/school_subject_model.dart';
import '../models/subject_style.dart';
import '../providers/academics_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: add a subject, or rename / restyle / delete one.
Future<void> showSubjectSheet(
  BuildContext context, {
  SchoolSubjectModel? subject,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SubjectSheet(subject: subject),
  );
}

class _SubjectSheet extends ConsumerStatefulWidget {
  final SchoolSubjectModel? subject;

  const _SubjectSheet({this.subject});

  @override
  ConsumerState<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends ConsumerState<_SubjectSheet> {
  late final _name = TextEditingController(text: widget.subject?.name);
  late String _icon = widget.subject?.iconKey ?? 'book';
  late String _color = widget.subject?.colorKey ?? 'blue';
  bool _saving = false;

  bool get _isNew => widget.subject == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      context.showMessage(tr('Write the subject name'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(academicsActionsProvider)
          .saveSubject(
            SchoolSubjectModel(
              id: widget.subject?.id ?? '',
              name: name,
              iconKey: _icon,
              colorKey: _color,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(_isNew ? tr('{0} added', [name]) : tr('Saved'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _delete() async {
    final subject = widget.subject!;
    final sure = await confirmDelete(
      context,
      title: tr('Delete {0}?', [subject.name]),
      message: subject.classCount == 0
          ? tr('No class studies it yet.')
          : subject.classCount == 1
          ? tr('It will also be removed from 1 class, with its teacher.')
          : tr(
              'It will also be removed from {0} classes, with their teacher assignments.',
              [subject.classCount],
            ),
    );
    if (!sure || !mounted) return;

    try {
      await ref.read(academicsActionsProvider).deleteSubject(subject);
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(tr('{0} deleted', [subject.name]));
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = SubjectStyle.color(_color);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? tr('New subject') : tr('Edit subject'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Name'),
                hintText: tr('e.g. Geography'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Colour'), style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in SubjectStyle.colors.entries)
                  InkWell(
                    onTap: () => setState(() => _color = entry.key),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: entry.value,
                      child: _color == entry.key
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Icon'), style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in SubjectStyle.icons.entries)
                  IconButton.filledTonal(
                    isSelected: _icon == entry.key,
                    onPressed: () => setState(() => _icon = entry.key),
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == entry.key
                          ? color.withValues(alpha: 0.2)
                          : null,
                      foregroundColor: _icon == entry.key ? color : null,
                    ),
                    icon: Icon(entry.value),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? tr('Add subject') : tr('Save')),
            ),
            if (!_isNew)
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete subject')),
              ),
          ],
        ),
      ),
    );
  }
}
