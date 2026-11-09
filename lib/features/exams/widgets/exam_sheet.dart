import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/exam_model.dart';
import '../providers/exam_provider.dart';
import '../../../core/l10n/language.dart';

/// Teacher or office: schedule an exam for a class, or change / delete one.
/// [subjects] are the (id, name) the user may choose from.
Future<void> showExamSheet(
  BuildContext context, {
  required String classId,
  required List<(String, String)> subjects,
  ExamModel? exam,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ExamSheet(classId: classId, subjects: subjects, exam: exam),
  );
}

class _ExamSheet extends ConsumerStatefulWidget {
  final String classId;
  final List<(String, String)> subjects;
  final ExamModel? exam;

  const _ExamSheet({required this.classId, required this.subjects, this.exam});

  @override
  ConsumerState<_ExamSheet> createState() => _ExamSheetState();
}

class _ExamSheetState extends ConsumerState<_ExamSheet> {
  static const _durations = [20, 30, 45, 60, 90, 120, 180];

  late String? _subjectId =
      widget.exam?.subject.id ??
      (widget.subjects.length == 1 ? widget.subjects.single.$1 : null);
  late ExamType _type = widget.exam?.type ?? ExamType.quiz;
  late final _title = TextEditingController(text: widget.exam?.title);
  late DateTime _start = widget.exam?.start ?? _tomorrowAtEight();
  late int _duration = widget.exam?.durationMinutes ?? 45;
  late final _room = TextEditingController(text: widget.exam?.room);
  late final _topics = TextEditingController(
    text: widget.exam?.topics.join(', '),
  );
  late final _maxScore = TextEditingController(
    text: _plain(widget.exam?.maxScore ?? 100),
  );
  bool _saving = false;

  bool get _isNew => widget.exam == null;

  static DateTime _tomorrowAtEight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8);
  }

  static String _plain(double n) =>
      n == n.roundToDouble() ? '${n.round()}' : '$n';

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _topics.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  /// "November monthly exam", "Mathematics quiz"... while the title is empty.
  String get _suggestedTitle {
    final month = DateFormatter.monthName(_start);
    final subject = widget.subjects
        .where((s) => s.$1 == _subjectId)
        .map((s) => s.$2)
        .firstOrNull;
    return switch (_type) {
      ExamType.monthly => tr('{0} monthly exam', [month]),
      ExamType.quiz => subject == null ? tr('Quiz') : tr('{0} quiz', [subject]),
      ExamType.midYear => tr('Mid-year exam'),
      ExamType.finalExam => tr('Final exam'),
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    final subjectId = _subjectId;
    final maxScore = double.tryParse(_maxScore.text);
    if (subjectId == null) {
      context.showMessage(tr('Choose the subject'));
      return;
    }
    if (maxScore == null || maxScore <= 0) {
      context.showMessage(tr('Write what the exam is out of'));
      return;
    }

    final draft = ExamDraftModel(
      classId: widget.classId,
      subjectId: subjectId,
      type: _type,
      title: _title.text.trim().isEmpty ? _suggestedTitle : _title.text.trim(),
      start: _start,
      durationMinutes: _duration,
      room: _room.text.trim(),
      topics: [
        for (final t in _topics.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      maxScore: maxScore,
    );

    setState(() => _saving = true);
    try {
      await ref
          .read(examActionsProvider)
          .saveExam(draft, examId: widget.exam?.id);
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(
        _isNew
            ? tr('{0} scheduled. Families are told.', [draft.title])
            : tr('Saved'),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _delete() async {
    final exam = widget.exam!;
    final sure = await confirmDelete(
      context,
      title: tr('Delete {0}?', [exam.displayTitle]),
      message: exam.scoredCount > 0
          ? tr('The {0} scores given for it are deleted too.', [
              exam.scoredCount,
            ])
          : tr('Students no longer see it.'),
    );
    if (!sure || !mounted) return;

    try {
      await ref.read(examActionsProvider).deleteExam(exam);
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(tr('{0} deleted', [exam.displayTitle]));
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _isNew ? tr('New exam') : tr('Edit exam'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.subjects.length > 1) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (id, name) in widget.subjects)
                    ChoiceChip(
                      label: Text(name),
                      selected: _subjectId == id,
                      onSelected: (_) => setState(() => _subjectId = id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final type in ExamType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Title'),
                hintText: _suggestedTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(DateFormatter.relativeDay(_start)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(DateFormatter.time(_start)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _durations.contains(_duration)
                        ? _duration
                        : null,
                    decoration: InputDecoration(labelText: tr('Length')),
                    items: [
                      for (final m in _durations)
                        DropdownMenuItem(
                          value: m,
                          child: Text(tr('{0} min', [m])),
                        ),
                    ],
                    onChanged: (m) => setState(() => _duration = m ?? 45),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _maxScore,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: tr('Out of')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _room,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Room (optional)'),
                hintText: tr('e.g. Hall A'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _topics,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Topics (optional)'),
                hintText: tr('Separate with commas'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? tr('Schedule exam') : tr('Save')),
            ),
            if (!_isNew) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete exam')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
