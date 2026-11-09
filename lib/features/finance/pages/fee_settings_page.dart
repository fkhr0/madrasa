import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../models/finance_settings_model.dart';
import '../providers/finance_provider.dart';
import '../repo/finance_repository.dart';
import '../../../core/l10n/language.dart';

/// Office: the year's fees. Tuition (and classes that pay a different
/// tuition), the bus fee for students on a bus line, and when the
/// installments are due. Every family's account follows these.
class FeeSettingsPage extends ConsumerWidget {
  const FeeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(financeSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Fees'))),
      body: AsyncValueView(
        value: settings,
        onRetry: () => ref.invalidate(financeSettingsProvider),
        data: (saved) => _Editor(saved: saved),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  final FinanceSettingsModel saved;

  const _Editor({required this.saved});

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _tuition = _field(widget.saved.tuition);
  late final _busFee = _field(widget.saved.busFee);
  late final List<DateTime> _dueDates = [...widget.saved.dueDates];

  /// Class ID → its tuition field (empty = the school's tuition).
  late final Map<String, TextEditingController> _classTuition = {
    for (final c in widget.saved.classTuition) c.classId: _field(c.tuition),
  };
  bool _saving = false;

  static TextEditingController _field(int? amount) =>
      TextEditingController(text: amount == null ? '' : '$amount');

  @override
  void dispose() {
    _tuition.dispose();
    _busFee.dispose();
    for (final f in _classTuition.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _addDate() async {
    final last = _dueDates.isEmpty ? DateTime.now() : _dueDates.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(last.year, last.month + 3, last.day),
      firstDate: DateTime(last.year - 1),
      lastDate: DateTime(last.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (!_dueDates.contains(picked)) _dueDates.add(picked);
      _dueDates.sort();
    });
  }

  Future<void> _removeDate(DateTime date) async {
    final sure = await confirmDelete(
      context,
      title: tr('Remove {0}?', [DateFormatter.fullDate(date)]),
      message: tr(
        'The year\'s fees are split over the dates that are left (when you save).',
      ),
      action: tr('Remove'),
    );
    if (sure) setState(() => _dueDates.remove(date));
  }

  Future<void> _save() async {
    final tuition = int.tryParse(_tuition.text);
    final busFee = int.tryParse(_busFee.text);
    if (tuition == null || busFee == null) {
      context.showMessage(tr('Write the tuition and the bus fee'));
      return;
    }
    if (_dueDates.isEmpty) {
      context.showMessage(tr('Add at least one due date'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(financeActionsProvider)
          .saveSettings(
            FinanceSettingsModel(
              tuition: tuition,
              busFee: busFee,
              dueDates: _dueDates,
              classTuition: [
                for (final c in widget.saved.classTuition)
                  ClassTuitionModel(
                    classId: c.classId,
                    className: c.className,
                    tuition: int.tryParse(_classTuition[c.classId]!.text),
                  ),
              ],
            ),
          );
      if (!mounted) return;
      context.showMessage(tr('Fees saved. Every account is updated.'));
      Navigator.of(context).pop();
    } on FinanceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget money(
      TextEditingController controller,
      String label, {
      String? hint,
    }) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: 'IQD',
        helperText: int.tryParse(controller.text) == null
            ? null
            : MoneyFormatter.iqd(int.parse(controller.text)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        money(_tuition, tr('Tuition for the year')),
        const SizedBox(height: AppSpacing.md),
        money(_busFee, tr('School bus for the year')),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('Only students on a bus line pay the bus fee.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: tr('Installments')),
        Text(
          tr('The year\'s fees are split evenly over these dates.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final (i, date) in _dueDates.indexed)
                ListTile(
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                  title: Text(DateFormatter.fullDate(date)),
                  subtitle: Text('${date.year}'),
                  trailing: IconButton(
                    tooltip: tr('Remove'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeDate(date),
                  ),
                ),
              if (_dueDates.length < 6)
                TextButton.icon(
                  onPressed: _addDate,
                  icon: const Icon(Icons.add),
                  label: Text(tr('Add a due date')),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (widget.saved.classTuition.isNotEmpty) ...[
          SectionHeader(title: tr('Tuition by class')),
          Text(
            tr('Leave empty to use the school\'s tuition.'),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in widget.saved.classTuition) ...[
            money(
              _classTuition[c.classId]!,
              c.className,
              hint: MoneyFormatter.grouped(int.tryParse(_tuition.text) ?? 0),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
        ],

        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(tr('Save fees')),
        ),
      ],
    );
  }
}
