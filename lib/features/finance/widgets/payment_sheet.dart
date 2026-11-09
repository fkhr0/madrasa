import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/money_formatter.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';
import '../providers/finance_provider.dart';
import '../repo/finance_repository.dart';
import '../../../core/l10n/language.dart';

/// Administrator: record money the office received.
/// Offers the amounts that usually make sense (overdue, next installment,
/// everything) so the clerk rarely types a number.
Future<void> showPaymentSheet(
  BuildContext context,
  StudentAccountModel account,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaymentSheet(account: account),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final StudentAccountModel account;

  const _PaymentSheet({required this.account});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setAmount(_suggestions().firstOrNull?.$2 ?? 0);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// (label, amount) shortcuts, without duplicates.
  List<(String, int)> _suggestions() {
    final account = widget.account;
    final DateTime now = ref.read(nowProvider);
    final overdue = account.overdueAmount(now);
    final next = account.nextDue();

    final options = [
      if (overdue > 0) (tr('Overdue'), overdue),
      if (next != null)
        (tr('{0} installment', [next.$1.name.split(' ').first]), next.$2),
      if (account.balance > 0) (tr('Whole balance'), account.balance),
    ];

    final seen = <int>{};
    return [
      for (final o in options)
        if (seen.add(o.$2)) o,
    ];
  }

  void _setAmount(int amount) =>
      _amount.text = amount == 0 ? '' : MoneyFormatter.grouped(amount);

  int get _typedAmount =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payment = await ref
          .read(financeActionsProvider)
          .recordPayment(
            studentId: widget.account.studentId,
            amount: _typedAmount,
            method: _method,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(
        tr('Saved · receipt {0}. The parent was notified.', [
          payment.receiptNumber,
        ]),
      );
    } on FinanceException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Record a payment'), style: context.text.titleLarge),
          Text(
            tr('{0} · balance {1}', [
              account.studentName,
              MoneyFormatter.iqd(account.balance),
            ]),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (label, amount) in _suggestions())
                ActionChip(
                  label: Text('$label · ${MoneyFormatter.compact(amount)}'),
                  onPressed: () => setState(() => _setAmount(amount)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9,]')),
            ],
            decoration: InputDecoration(
              labelText: tr('Amount'),
              suffixText: 'IQD',
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in PaymentMethod.values)
                ChoiceChip(
                  avatar: Icon(m.icon, size: 18),
                  label: Text(m.label),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: tr('Note (optional)'),
              hintText: tr('e.g. paid by the uncle'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(tr('Save payment')),
          ),
        ],
      ),
    );
  }
}
