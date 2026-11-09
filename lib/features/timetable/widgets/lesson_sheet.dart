import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../academics/models/school_class_model.dart';
import '../../academics/providers/academics_provider.dart';
import '../models/class_timetable_model.dart';
import '../models/period_model.dart';
import '../models/timetable_lesson_model.dart';
import '../providers/timetable_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: choose the subject (and room) of one period of a class,
/// or free the period.
Future<void> showLessonSheet(
  BuildContext context, {
  required SchoolClassModel schoolClass,
  required ClassTimetableModel timetable,
  required int weekday,
  required PeriodModel period,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LessonSheet(
      schoolClass: schoolClass,
      timetable: timetable,
      weekday: weekday,
      period: period,
    ),
  );
}

class _LessonSheet extends ConsumerStatefulWidget {
  final SchoolClassModel schoolClass;
  final ClassTimetableModel timetable;
  final int weekday;
  final PeriodModel period;

  const _LessonSheet({
    required this.schoolClass,
    required this.timetable,
    required this.weekday,
    required this.period,
  });

  @override
  ConsumerState<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends ConsumerState<_LessonSheet> {
  late final TimetableLessonModel? _lesson = widget.timetable.lessonAt(
    widget.weekday,
    widget.period.number,
  );
  late String? _subjectId = _lesson?.subjectId;
  late final _room = TextEditingController(text: _lesson?.room);
  bool _saving = false;

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  /// The room filled in by [_pick], so a typed room is never overwritten.
  String? _suggestedRoom;

  /// Picking a subject fills in the room it usually has in this class.
  void _pick(String subjectId) {
    setState(() => _subjectId = subjectId);
    if (_room.text.isNotEmpty && _room.text != _suggestedRoom) return;

    final usual = widget.timetable.lessons
        .where((l) => l.subjectId == subjectId && l.room.isNotEmpty)
        .map((l) => l.room)
        .firstOrNull;
    _room.text = _suggestedRoom = usual ?? '';
  }

  Future<void> _save() async {
    final subjectId = _subjectId;
    if (subjectId == null) {
      context.showMessage(tr('Choose a subject'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(timetableActionsProvider)
          .setLesson(
            classId: widget.schoolClass.id,
            weekday: widget.weekday,
            period: widget.period.number,
            subjectId: subjectId,
            room: _room.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _remove() async {
    final lesson = _lesson!;
    final sure = await confirmDelete(
      context,
      title: tr('Remove {0}?', [lesson.subjectName]),
      message: tr('Period {0} on {1} becomes free for {2}.', [
        lesson.period,
        DateFormatter.weekdayName(lesson.weekday),
        widget.schoolClass.name,
      ]),
      action: tr('Remove'),
    );
    if (!sure || !mounted) return;

    try {
      await ref
          .read(timetableActionsProvider)
          .deleteLesson(
            classId: widget.schoolClass.id,
            weekday: widget.weekday,
            period: widget.period.number,
          );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(schoolSubjectsProvider).valueOrNull ?? [];
    final style = {for (final s in catalogue) s.id: s};

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
              tr('{0} · Period {1}', [
                DateFormatter.weekdayName(widget.weekday),
                widget.period.number,
              ]),
              style: context.text.titleLarge,
            ),
            Text(
              '${widget.period.label} · ${widget.schoolClass.name}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.schoolClass.subjects.isEmpty)
              Text(
                tr(
                  'This class has no subjects yet. Add them on the class page.',
                ),
                style: context.text.bodyMedium,
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in widget.schoolClass.subjects)
                  ChoiceChip(
                    avatar: Icon(
                      style[s.subjectId]?.icon ?? Icons.menu_book_outlined,
                      size: 18,
                      color: style[s.subjectId]?.color,
                    ),
                    label: Text(s.subjectName),
                    selected: _subjectId == s.subjectId,
                    onSelected: (_) => _pick(s.subjectId),
                  ),
              ],
            ),
            if (_teacherNote() case final note?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                note,
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _room,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Room (optional)'),
                hintText: tr('e.g. Room 204, Lab 2'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_lesson == null ? tr('Add lesson') : tr('Save')),
            ),
            if (_lesson != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Remove lesson')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A hint when the chosen subject has no teacher in this class yet.
  String? _teacherNote() {
    for (final s in widget.schoolClass.subjects) {
      if (s.subjectId == _subjectId && !s.hasTeacher) {
        return tr('No teacher teaches {0} in this class yet.', [s.subjectName]);
      }
    }
    return null;
  }
}
