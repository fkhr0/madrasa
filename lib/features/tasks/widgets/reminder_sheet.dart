import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../../../core/l10n/language.dart';

/// "Remind me", one sheet used everywhere (dashboard, assignments, exams,
/// planner tips, tasks).
Future<void> showReminderSheet(
  BuildContext context, {
  String title = '',
  DateTime? before,
  String? route,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ReminderSheet(initialTitle: title, before: before, route: route),
  );
}

class _ReminderSheet extends ConsumerStatefulWidget {
  final String initialTitle;
  final DateTime? before;
  final String? route;

  const _ReminderSheet({
    required this.initialTitle,
    required this.before,
    required this.route,
  });

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final List<(String, DateTime)> _choices = _buildChoices();
  late DateTime _when = _choices[1].$2;
  TaskRepeat _repeat = TaskRepeat.none;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Quick times that make sense right now.
  List<(String, DateTime)> _buildChoices() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final before = widget.before;

    return [
      // Handy for trying reminders out.
      (tr('In 1 minute'), now.add(const Duration(minutes: 1))),
      (tr('In 1 hour'), now.add(const Duration(hours: 1))),
      if (now.hour < 19)
        (tr('Tonight 8 pm'), today.add(const Duration(hours: 20))),
      (tr('Tomorrow 7 am'), today.add(const Duration(days: 1, hours: 7))),
      if (before != null && before.difference(now).inHours > 24)
        (
          tr('Evening before'),
          DateTime(before.year, before.month, before.day - 1, 19),
        ),
    ];
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;

    setState(() => _when = date.copyWith(hour: time.hour, minute: time.minute));
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    ref
        .read(tasksProvider.notifier)
        .add(
          TaskModel(
            id: 'r${DateTime.now().microsecondsSinceEpoch}',
            title: title,
            dueAt: _when,
            repeat: _repeat,
            isReminder: true,
            route: widget.route,
          ),
        );

    Navigator.of(context).pop();
    context.showMessage(
      tr('Reminder set for {0} at {1}', [
        DateFormatter.relativeDay(_when).toLowerCase(),
        DateFormatter.time(_when),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !_choices.any((c) => c.$2 == _when);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Remind me'), style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _title,
              autofocus: widget.initialTitle.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: tr('What should we remind you about?'),
                prefixIcon: Icon(Icons.alarm),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('When'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (label, time) in _choices)
                  ChoiceChip(
                    label: Text(label),
                    selected: _when == time,
                    onSelected: (_) => setState(() => _when = time),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: Text(
                    isCustom
                        ? '${DateFormatter.relativeDay(_when)}, '
                              '${DateFormatter.time(_when)}'
                        : tr('Pick a time'),
                  ),
                  selected: isCustom,
                  onSelected: (_) => _pickCustom(),
                ),
              ],
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
                    selected: _repeat == r,
                    onSelected: (_) => setState(() => _repeat = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.alarm_add),
              label: Text(tr('Set reminder')),
            ),
          ],
        ),
      ),
    );
  }
}
