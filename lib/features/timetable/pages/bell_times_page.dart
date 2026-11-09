import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/period_model.dart';
import '../providers/timetable_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: the school's bell times, the same for every class.
/// Changes are kept here until Save.
class BellTimesPage extends ConsumerWidget {
  const BellTimesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(periodsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Bell times'))),
      body: AsyncValueView(
        value: periods,
        onRetry: () => ref.invalidate(periodsProvider),
        data: (saved) => _BellTimesEditor(saved: saved),
      ),
    );
  }
}

class _BellTimesEditor extends ConsumerStatefulWidget {
  final List<PeriodModel> saved;

  const _BellTimesEditor({required this.saved});

  @override
  ConsumerState<_BellTimesEditor> createState() => _BellTimesEditorState();
}

class _BellTimesEditorState extends ConsumerState<_BellTimesEditor> {
  late final List<(TimeOfDay, TimeOfDay)> _periods = [
    for (final p in widget.saved) (_parse(p.start), _parse(p.end)),
  ];
  bool _saving = false;

  static TimeOfDay _parse(String time) {
    final [hour, minute] = time.split(':').map(int.parse).toList();
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _text(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _plus(TimeOfDay t, int minutes) {
    final total = (t.hour * 60 + t.minute + minutes).clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  Future<void> _pickTime(int index, {required bool start}) async {
    final (from, to) = _periods[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? from : to,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;

    setState(() {
      _periods[index] = start ? (picked, to) : (from, picked);
    });
  }

  void _addPeriod() {
    setState(() {
      final last = _periods.lastOrNull;
      final start = last == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : _plus(last.$2, 5);
      _periods.add((start, _plus(start, 45)));
    });
  }

  Future<void> _removeLast() async {
    final sure = await confirmDelete(
      context,
      title: tr('Remove period {0}?', [_periods.length]),
      message: tr('It is removed when you save.'),
      action: tr('Remove'),
    );
    if (sure) setState(() => _periods.removeLast());
  }

  /// The first problem in the list, or null when it can be saved.
  String? get _problem {
    for (var i = 0; i < _periods.length; i++) {
      final (start, end) = _periods[i];
      if (_minutes(end) <= _minutes(start)) {
        return tr('Period {0} must end after it starts.', [i + 1]);
      }
      if (i > 0 && _minutes(start) < _minutes(_periods[i - 1].$2)) {
        return tr('Period {0} starts before period {1} ends.', [i + 1, i]);
      }
    }
    return null;
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _save() async {
    final periods = [
      for (final (i, (start, end)) in _periods.indexed)
        PeriodModel(number: i + 1, start: _text(start), end: _text(end)),
    ];
    final actions = ref.read(timetableActionsProvider);

    setState(() => _saving = true);
    try {
      try {
        await actions.savePeriods(periods);
      } on ApiException catch (e) {
        // Lessons sit in the periods being cut: ask, then save again.
        if (e.status != 409 || !mounted) rethrow;
        final sure = await confirmDelete(
          context,
          title: tr('Remove those lessons?'),
          message: e.message,
          action: tr('Remove and save'),
        );
        if (!sure) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await actions.savePeriods(periods, removeLessons: true);
      }
      if (!mounted) return;
      context.showMessage(tr('Bell times saved'));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        Text(
          tr('Every class follows these times. Tap a time to change it.'),
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final (i, (start, end)) in _periods.indexed) ...[
          if (i > 0)
            _Gap(minutes: _minutes(start) - _minutes(_periods[i - 1].$2)),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Period {0}', [i + 1]),
                    style: context.text.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _pickTime(i, start: true),
                  child: Text(_text(start)),
                ),
                const Text('–'),
                TextButton(
                  onPressed: () => _pickTime(i, start: false),
                  child: Text(_text(end)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _periods.length >= 12 ? null : _addPeriod,
                icon: const Icon(Icons.add),
                label: Text(tr('Add period')),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _periods.length <= 1 ? null : _removeLast,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.remove),
                label: Text(tr('Remove last')),
              ),
            ),
          ],
        ),
        if (problem != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            problem,
            style: context.text.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving || problem != null ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}

/// The break between two periods, e.g. "20 min break".
class _Gap extends StatelessWidget {
  final int minutes;

  const _Gap({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final isBreak = minutes >= 15;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Text(
          minutes <= 0
              ? tr('no gap')
              : isBreak
              ? tr('{0} min break', [minutes])
              : tr('{0} min', [minutes]),
          style: context.text.bodySmall?.copyWith(
            color: isBreak
                ? context.palette.primary
                : context.palette.textMuted,
          ),
        ),
      ),
    );
  }
}
