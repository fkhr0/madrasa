import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../../../core/l10n/language.dart';

/// Opens the "New task" bottom sheet.
Future<void> showAddTaskSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddTaskSheet(),
  );
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet();

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _dueAt = _defaultDue();
  TaskPriority _priority = TaskPriority.medium;
  TaskRepeat _repeat = TaskRepeat.none;

  /// One hour from now, rounded to the hour.
  static DateTime _defaultDue() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return DateTime(now.year, now.month, now.day, now.hour);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final note = _noteController.text.trim();
    ref
        .read(tasksProvider.notifier)
        .add(
          TaskModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            note: note.isEmpty ? null : note,
            dueAt: _dueAt,
            priority: _priority,
            repeat: _repeat,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Moves the sheet up above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('New task'), style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: tr('What do you need to do?'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Note (optional)')),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(DateFormatter.relativeDay(_dueAt)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(DateFormatter.time(_dueAt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Priority'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<TaskPriority>(
              showSelectedIcon: false,
              segments: [
                for (final p in TaskPriority.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Repeat'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in TaskRepeat.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: r == _repeat,
                    onSelected: (_) => setState(() => _repeat = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: _save, child: Text(tr('Add task'))),
          ],
        ),
      ),
    );
  }
}
