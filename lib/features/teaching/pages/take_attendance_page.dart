import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../attendance/models/attendance_record_model.dart';
import '../../attendance/models/class_lesson_model.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/attendance_toggle.dart';
import '../../../core/l10n/language.dart';

/// Attendance for one lesson of a class.
class TakeAttendancePage extends ConsumerStatefulWidget {
  final String classId;

  const TakeAttendancePage({super.key, required this.classId});

  /// How far back a teacher may still correct (the server checks too).
  static const teacherDaysBack = 7;

  @override
  ConsumerState<TakeAttendancePage> createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends ConsumerState<TakeAttendancePage> {
  late DateTime _date = _dateOnly(DateTime.now());

  /// The chosen lesson; null = the current one (or the latest of the day).
  int? _period;

  /// Student ID → status the user changed and hasn't saved yet.
  final Map<String, AttendanceStatus> _edits = {};
  bool _saving = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _today => _dateOnly(DateTime.now());

  void _goTo(DateTime date) => setState(() {
    _date = date;
    _period = null;
    _edits.clear();
  });

  /// The lesson running now, else the last one that started, else the first.
  ClassLessonModel _defaultLesson(List<ClassLessonModel> lessons) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    if (_date != _today) return lessons.first;

    return lessons.lastWhere(
      (l) => l.start.compareTo(time) <= 0,
      orElse: () => lessons.first,
    );
  }

  Future<void> _save(
    ClassLessonModel lesson,
    List<StudentMarkModel> students,
  ) async {
    final marks = {for (final s in students) s.id: _statusOf(s)};
    final absent = marks.values.where((m) => m == AttendanceStatus.absent);

    setState(() => _saving = true);
    try {
      await ref
          .read(attendanceActionsProvider)
          .saveLessonMarks(widget.classId, _date, lesson.period, marks);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _edits.clear();
      });
      context.showMessage(
        absent.isEmpty
            ? tr('Attendance saved')
            : tr('Attendance saved. Families of absent students are told.'),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  AttendanceStatus _statusOf(StudentMarkModel s) =>
      _edits[s.id] ?? s.status ?? AttendanceStatus.present;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider).role == UserRole.admin;
    final earliest = isAdmin
        ? null
        : _today.subtract(
            const Duration(days: TakeAttendancePage.teacherDaysBack),
          );
    final day = ref.watch(classDayProvider((widget.classId, _date)));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Attendance')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _DateBar(
            date: _date,
            onPrevious: earliest != null && !_date.isAfter(earliest)
                ? null
                : () => _goTo(_date.subtract(const Duration(days: 1))),
            onNext: _date == _today
                ? null
                : () => _goTo(_date.add(const Duration(days: 1))),
          ),
        ),
      ),
      body: AsyncValueView(
        value: day,
        onRetry: () =>
            ref.invalidate(classDayProvider((widget.classId, _date))),
        data: (day) {
          if (!day.isSchoolDay) {
            return EmptyState(
              icon: Icons.weekend_outlined,
              title: tr('No school on this day'),
            );
          }
          if (day.lessons.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: isAdmin
                  ? tr('{0} has no lessons this day', [day.className])
                  : tr('You have no lesson with {0} this day', [day.className]),
            );
          }

          final lesson = day.lessons.firstWhere(
            (l) => l.period == _period,
            orElse: () => _defaultLesson(day.lessons),
          );

          return Column(
            children: [
              _LessonChips(
                className: day.className,
                lessons: day.lessons,
                selected: lesson,
                onSelected: (l) => setState(() {
                  _period = l.period;
                  _edits.clear();
                }),
              ),
              Expanded(child: _sheetFor(lesson)),
            ],
          );
        },
      ),
    );
  }

  Widget _sheetFor(ClassLessonModel lesson) {
    final key = (widget.classId, _date, lesson.period);

    return AsyncValueView(
      value: ref.watch(lessonSheetProvider(key)),
      onRetry: () => ref.invalidate(lessonSheetProvider(key)),
      data: (students) {
        if (students.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: tr('No students in this class'),
          );
        }
        int count(AttendanceStatus status) =>
            students.where((s) => _statusOf(s) == status).length;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                children: [
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, s) in students.indexed) ...[
                          if (i > 0)
                            const Divider(
                              indent: AppSpacing.lg,
                              endIndent: AppSpacing.lg,
                            ),
                          _StudentLine(
                            student: s,
                            status: _statusOf(s),
                            onChanged: (status) =>
                                setState(() => _edits[s.id] = status),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              summary: tr('{0} present · {1} late · {2} absent', [
                count(AttendanceStatus.present),
                count(AttendanceStatus.late),
                count(AttendanceStatus.absent),
              ]),
              label: lesson.taken ? tr('Save changes') : tr('Save attendance'),
              isSaving: _saving,
              onSave: lesson.taken && _edits.isEmpty
                  ? null
                  : () => _save(lesson, students),
            ),
          ],
        );
      },
    );
  }
}

class _DateBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _DateBar({required this.date, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: tr('Day before'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${DateFormatter.relativeDay(date)} · ${DateFormatter.fullDate(date)}',
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
        ),
        IconButton(
          tooltip: tr('Day after'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _LessonChips extends StatelessWidget {
  final String className;
  final List<ClassLessonModel> lessons;
  final ClassLessonModel selected;
  final ValueChanged<ClassLessonModel> onSelected;

  const _LessonChips({
    required this.className,
    required this.lessons,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(className, style: context.text.titleMedium),
          Text(
            tr('Period {0} · {1} – {2} · {3}{4}', [
              selected.period,
              selected.start,
              selected.end,
              selected.subjectName,
              selected.taken ? tr(' · taken') : '',
            ]),
            style: context.text.bodySmall,
          ),
          if (lessons.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final l in lessons)
                  ChoiceChip(
                    avatar: l.taken ? const Icon(Icons.check, size: 16) : null,
                    label: Text('P${l.period} · ${l.subjectName}'),
                    selected: l.period == selected.period,
                    onSelected: (_) => onSelected(l),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentLine extends StatelessWidget {
  final StudentMarkModel student;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  const _StudentLine({
    required this.student,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          UserAvatar(name: student.name, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              student.name,
              style: context.text.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AttendanceToggle(value: status, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String summary;
  final String label;
  final bool isSaving;

  /// Null when there is nothing to save.
  final VoidCallback? onSave;

  const _BottomBar({
    required this.summary,
    required this.label,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              summary,
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: isSaving ? null : onSave,
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
