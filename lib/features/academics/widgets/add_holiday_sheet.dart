import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../institution/models/academic_year_model.dart';
import '../../institution/models/holiday_model.dart';
import '../../institution/providers/institution_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/l10n/language.dart';

/// Lets the administrator add a day off (or several) to the study year, e.g.
Future<void> showAddHolidaySheet(
  BuildContext context,
  AcademicYearModel year, {
  HolidayModel? holiday,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddHolidaySheet(year: year, holiday: holiday),
  );
}

class _AddHolidaySheet extends ConsumerStatefulWidget {
  final AcademicYearModel year;
  final HolidayModel? holiday;

  const _AddHolidaySheet({required this.year, this.holiday});

  @override
  ConsumerState<_AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends ConsumerState<_AddHolidaySheet> {
  late final _name = TextEditingController(text: widget.holiday?.name);
  late HolidayType _type = widget.holiday?.type ?? HolidayType.national;

  bool get _isOfficial => widget.holiday?.isOfficial ?? false;
  late DateTime _start =
      widget.holiday?.start ?? widget.year.clamp(DateTime.now());
  late DateTime? _end = widget.holiday?.end;

  bool get _isNew => widget.holiday == null;

  // A getter, so the words follow the language chosen now.
  static Map<HolidayType, String> get _typeLabels => {
    HolidayType.national: tr('Official'),
    HolidayType.religious: tr('Religious'),
    HolidayType.schoolBreak: tr('School break'),
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, DateTime first) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: widget.year.end,
  );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;

    final holiday = HolidayModel(
      name: _name.text.trim(),
      type: _type,
      start: _start,
      end: _end,
      isOfficial: _isOfficial,
    );
    final actions = ref.read(institutionActionsProvider);

    try {
      if (widget.holiday case final old?) {
        await actions.updateHoliday(old, holiday);
      } else {
        await actions.addHoliday(holiday);
      }
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? tr('Add a holiday') : tr('Edit holiday'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Official holidays: only the dates can move (moon sighting).
            if (_isOfficial)
              Text(
                tr(
                  '{0} is an official holiday. You can move its dates if the official announcement differs.',
                  [widget.holiday!.name],
                ),
                style: context.text.bodyMedium,
              )
            else ...[
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('Name, e.g. Eid al-Fitr'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final entry in _typeLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await _pick(_start, widget.year.start);
                      if (date != null) {
                        setState(() {
                          _start = date;
                          if (_end != null && _end!.isBefore(date)) _end = null;
                        });
                      }
                    },
                    child: Text(
                      tr('From {0}', [DateFormatter.dayMonth(_start)]),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await _pick(_end ?? _start, _start);
                      if (date != null) setState(() => _end = date);
                    },
                    child: Text(
                      _end == null
                          ? tr('One day')
                          : tr('To {0}', [DateFormatter.dayMonth(_end!)]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _save,
              child: Text(_isNew ? tr('Add holiday') : tr('Save')),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('Everyone sees it on their calendar and schedule.'),
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
