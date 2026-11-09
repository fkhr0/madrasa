import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../institution/models/academic_year_model.dart';
import '../models/calendar_event_model.dart';
import '../models/school_event_model.dart';
import '../providers/calendar_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: add an event or meeting to the school calendar, or change
/// or delete one ([event] given). Dates stay inside the study year.
Future<void> showEventEditor(
  BuildContext context, {
  required AcademicYearModel year,
  required DateTime day,
  SchoolEventModel? event,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventEditor(year: year, day: day, event: event),
  );
}

class _EventEditor extends ConsumerStatefulWidget {
  final AcademicYearModel year;
  final DateTime day;
  final SchoolEventModel? event;

  const _EventEditor({required this.year, required this.day, this.event});

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _place = TextEditingController(text: widget.event?.place);
  late final _details = TextEditingController(text: widget.event?.details);
  late CalendarEventType _type = widget.event?.type ?? CalendarEventType.event;
  late EventAudience _audience =
      widget.event?.audience ?? EventAudience.everyone;
  late DateTime _date = widget.event?.date ?? widget.day;
  late DateTime? _endDate = widget.event?.endDate;
  late int? _startMinute = widget.event == null
      ? 9 * 60
      : widget.event!.startMinute;
  bool _saving = false;

  bool get _isNew => widget.event == null;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first ?? widget.year.start,
        lastDate: widget.year.end,
      );

  Future<void> _pickTime() async {
    final m = _startMinute ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      setState(() => _startMinute = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      context.showMessage(tr('Give the event a title'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(calendarActionsProvider)
          .saveEvent(
            SchoolEventModel(
              id: widget.event?.id ?? '',
              title: _title.text.trim(),
              type: _type,
              audience: _audience,
              date: _date,
              startMinute: _startMinute,
              endDate: _endDate,
              place: _place.text.trim(),
              details: _details.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(_isNew ? tr('Added to the calendar') : tr('Saved'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _delete() async {
    final event = widget.event!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete "{0}"?', [event.title])),
        content: Text(tr('It disappears from everyone\'s calendar.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    try {
      await ref.read(calendarActionsProvider).deleteEvent(event);
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(tr('Deleted'));
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = _startMinute;

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
              _isNew ? tr('New on the calendar') : tr('Edit'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final type in [
                  CalendarEventType.event,
                  CalendarEventType.meeting,
                ])
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() {
                      _type = type;
                      // Meetings are usually not for students.
                      if (type == CalendarEventType.meeting &&
                          _audience == EventAudience.everyone) {
                        _audience = EventAudience.families;
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Title'),
                hintText: tr('e.g. Science fair'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(tr('Who sees it'), style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final audience in EventAudience.values)
                  ChoiceChip(
                    label: Text(audience.label),
                    selected: _audience == audience,
                    onSelected: (_) => setState(() => _audience = audience),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await _pickDate(_date);
                      if (d == null) return;
                      setState(() {
                        _date = d;
                        if (_endDate != null && _endDate!.isBefore(d)) {
                          _endDate = null;
                        }
                      });
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(DateFormatter.dayMonth(_date)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: time == null ? null : _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      time == null
                          ? tr('All day')
                          : DateFormatter.time(
                              _date.add(Duration(minutes: time)),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('All day')),
              value: time == null,
              onChanged: (allDay) =>
                  setState(() => _startMinute = allDay ? null : 9 * 60),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Several days')),
              subtitle: _endDate == null
                  ? null
                  : Text(tr('Until {0}', [DateFormatter.fullDate(_endDate!)])),
              value: _endDate != null,
              onChanged: (on) async {
                if (!on) {
                  setState(() => _endDate = null);
                  return;
                }
                final d = await _pickDate(
                  _date.add(const Duration(days: 1)),
                  first: _date,
                );
                if (d != null) setState(() => _endDate = d);
              },
            ),
            TextField(
              controller: _place,
              decoration: InputDecoration(
                labelText: tr('Place (optional)'),
                hintText: tr('e.g. Main hall'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _details,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('Details (optional)'),
                hintText: tr('e.g. Bring the signed permission slip'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? tr('Add to calendar') : tr('Save')),
            ),
            if (!_isNew)
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete')),
              ),
          ],
        ),
      ),
    );
  }
}
