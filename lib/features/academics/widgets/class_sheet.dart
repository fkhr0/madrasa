import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/school_class_model.dart';
import '../providers/academics_provider.dart';
import 'teacher_picker_sheet.dart';
import '../../../core/l10n/language.dart';

/// Administrator: a new class (name, head teacher, subjects), or rename a
/// class and change its head teacher ([schoolClass] given).
/// Returns true when the class was deleted.
Future<bool?> showClassSheet(
  BuildContext context, {
  SchoolClassModel? schoolClass,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ClassSheet(schoolClass: schoolClass),
  );
}

class _ClassSheet extends ConsumerStatefulWidget {
  final SchoolClassModel? schoolClass;

  const _ClassSheet({this.schoolClass});

  @override
  ConsumerState<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends ConsumerState<_ClassSheet> {
  late final _name = TextEditingController(text: widget.schoolClass?.name);
  late String? _headId = widget.schoolClass?.homeroomTeacherId;
  late String? _headName = widget.schoolClass?.homeroomTeacherName;

  /// New classes: the subjects it studies (all of them by default).
  Set<String>? _subjectIds;
  bool _saving = false;

  bool get _isNew => widget.schoolClass == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickHead() async {
    final choice = await showTeacherPicker(
      context,
      title: tr('Head of the class'),
      currentId: _headId,
    );
    if (choice == null) return;
    setState(() {
      _headId = choice.teacher?.id;
      _headName = choice.teacher?.name;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      context.showMessage(tr('Write the class name, e.g. 4th Scientific – B'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(academicsActionsProvider)
          .saveClass(
            classId: widget.schoolClass?.id,
            name: name,
            homeroomTeacherId: _headId,
            subjectIds: _subjectIds?.toList() ?? const [],
          );
      if (!mounted) return;
      Navigator.pop(context, false);
      context.showMessage(_isNew ? tr('{0} added', [name]) : tr('Saved'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _delete() async {
    final schoolClass = widget.schoolClass!;
    if (schoolClass.studentCount > 0) {
      context.showMessage(
        tr('{0} has {1} students. Move them to another class first.', [
          schoolClass.name,
          schoolClass.studentCount,
        ]),
      );
      return;
    }

    final sure = await confirmDelete(
      context,
      title: tr('Delete {0}?', [schoolClass.name]),
      message: tr('Its subjects and teacher assignments are removed too.'),
    );
    if (!sure || !mounted) return;

    try {
      await ref.read(academicsActionsProvider).deleteClass(schoolClass);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(schoolSubjectsProvider).valueOrNull ?? [];
    final chosen = _subjectIds ??= {for (final s in subjects) s.id};

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
              _isNew ? tr('New class') : tr('Edit class'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('Class name'),
                hintText: tr('e.g. 4th Scientific – B'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: Text(tr('Head of the class')),
              subtitle: Text(_headName ?? tr('Not chosen — tap to choose')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickHead,
            ),
            if (_isNew && subjects.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(tr('Subjects it studies'), style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in subjects)
                    FilterChip(
                      avatar: Icon(s.icon, size: 16, color: s.color),
                      label: Text(s.name),
                      selected: chosen.contains(s.id),
                      onSelected: (on) => setState(
                        () => on ? chosen.add(s.id) : chosen.remove(s.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr('You choose the teachers on the class page.'),
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? tr('Add class') : tr('Save')),
            ),
            if (!_isNew)
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete class')),
              ),
          ],
        ),
      ),
    );
  }
}
