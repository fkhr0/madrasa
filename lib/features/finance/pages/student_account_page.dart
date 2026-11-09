import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/payment_model.dart';
import '../repo/finance_repository.dart';
import '../models/student_account_model.dart';
import '../providers/finance_provider.dart';
import '../widgets/installment_list.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/payment_tile.dart';
import '../../../core/l10n/language.dart';

/// One student's fees. Administrators can record payments and remind the
/// parent; parents see the same page read-only (via FeesPage).
class StudentAccountPage extends ConsumerWidget {
  final String studentId;

  const StudentAccountPage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider(studentId));
    final isAdmin = ref.watch(currentUserProvider).role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.valueOrNull?.studentName ?? tr('Fees')),
      ),
      floatingActionButton: isAdmin && (account.valueOrNull?.balance ?? 0) > 0
          ? FloatingActionButton.extended(
              onPressed: () => showPaymentSheet(context, account.value!),
              icon: const Icon(Icons.add_card),
              label: Text(tr('Record payment')),
            )
          : null,
      body: AsyncValueView(
        value: account,
        data: (account) => account == null
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: tr('No fees on file'),
              )
            : StudentAccountView(account: account, isAdmin: isAdmin),
      ),
    );
  }
}

/// The account itself, shared by the admin page and the parent's Fees page.
class StudentAccountView extends ConsumerWidget {
  final StudentAccountModel account;
  final bool isAdmin;

  /// Shown above the account (the parent's child switcher).
  final Widget header;

  const StudentAccountView({
    super.key,
    required this.account,
    required this.isAdmin,
    this.header = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final status = account.status(now);
    final overdue = account.overdueAmount(now);
    final next = account.nextDue();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        96,
      ),
      children: [
        header,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.balance == 0 ? tr('All paid') : tr('Balance'),
                      style: context.text.labelLarge,
                    ),
                  ),
                  StatusBadge(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MoneyFormatter.iqd(
                  account.balance == 0 ? account.paid : account.balance,
                ),
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: account.total == 0 ? 1 : account.paid / account.total,
                  minHeight: 8,
                  color: AppColors.success,
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                overdue > 0
                    ? tr('{0} is overdue. Please pay at the school office.', [
                        MoneyFormatter.iqd(overdue),
                      ])
                    : next == null
                    ? tr('Thank you — nothing more is due this year.')
                    : tr('Next: {0} by {1}', [
                        MoneyFormatter.iqd(next.$2),
                        DateFormatter.fullDate(next.$1.dueDate),
                      ]),
                style: context.text.bodyMedium?.copyWith(
                  color: overdue > 0 ? AppColors.danger : null,
                ),
              ),
            ],
          ),
        ),
        if (isAdmin && account.balance > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(financeActionsProvider)
                    .remindParent(account.studentId);
                if (context.mounted) {
                  context.showMessage(
                    tr('Reminder sent to {0}', [account.parentName]),
                  );
                }
              } on FinanceException catch (e) {
                if (context.mounted) context.showMessage(e.message);
              }
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: Text(tr('Remind the parent')),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: tr('Installments')),
        InstallmentList(account: account, now: now),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: tr('Fees this year')),
        _Breakdown(account: account),
        if (isAdmin)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _changeDiscount(context, ref),
              icon: const Icon(Icons.percent, size: 18),
              label: Text(
                account.discountPercent == 0
                    ? tr('Give a discount')
                    : tr('Change discount'),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: tr('Payments ({0})', [account.payments.length])),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: account.payments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    tr('No payments yet'),
                    style: context.text.bodyMedium,
                  ),
                )
              : Column(
                  children: [
                    for (final p in account.payments.reversed)
                      PaymentTile(
                        payment: p,
                        onTap: isAdmin
                            ? () => _voidPayment(context, ref, p)
                            : null,
                      ),
                  ],
                ),
        ),
        if (!isAdmin) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: tr('How to pay')),
          AppCard(
            child: Text(
              tr(
                'Pay at the school office (cash or card) from Sunday to Thursday, 8:00–13:00, or by bank transfer with the student ID {0} as the reference. Every payment shows up here with its receipt number.',
                [account.studentId],
              ),
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

extension on StudentAccountView {
  /// The office voids a wrong payment: it stays in the records but no
  /// longer counts.
  Future<void> _voidPayment(
    BuildContext context,
    WidgetRef ref,
    PaymentModel payment,
  ) async {
    final reason = await _askReason(
      context,
      title: tr('Void {0}?', [payment.receiptNumber]),
      message: tr(
        '{0} will no longer count. The receipt stays in the records.',
        [MoneyFormatter.iqd(payment.amount)],
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(financeActionsProvider).voidPayment(payment, reason);
      if (context.mounted) {
        context.showMessage(tr('{0} voided', [payment.receiptNumber]));
      }
    } on FinanceException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  Future<void> _changeDiscount(BuildContext context, WidgetRef ref) async {
    final percent = TextEditingController(
      text: account.discountPercent == 0 ? '' : '${account.discountPercent}',
    );
    final reason = TextEditingController(text: account.discountReason);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Discount on tuition')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: percent,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Percent (0 removes it)'),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reason,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Reason'),
                hintText: tr('e.g. Siblings at the school'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    final value = int.tryParse(percent.text.trim()) ?? 0;
    final why = reason.text.trim();
    percent.dispose();
    reason.dispose();
    if (save != true || !context.mounted) return;

    if (value < 0 || value > 100) {
      context.showMessage(tr('Choose between 0 and 100%'));
      return;
    }
    try {
      await ref
          .read(financeActionsProvider)
          .setDiscount(account.studentId, value, why);
    } on FinanceException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }
}

/// Asks for a reason before something is voided; null when cancelled.
Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final text = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: text,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('Reason'),
              hintText: tr('e.g. Entered twice'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            if (text.text.trim().length >= 3) {
              Navigator.pop(dialogContext, text.text.trim());
            }
          },
          child: Text(tr('Void payment')),
        ),
      ],
    ),
  );
  text.dispose();
  return result;
}

class _Breakdown extends StatelessWidget {
  final StudentAccountModel account;

  const _Breakdown({required this.account});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int amount, {bool bold = false, Color? color}) {
      final style = bold ? context.text.titleSmall : context.text.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(
              MoneyFormatter.iqd(amount),
              style: style?.copyWith(color: color),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          row(tr('Tuition'), account.tuition),
          if (account.busFee > 0) row(tr('School bus'), account.busFee),
          if (account.discount > 0)
            row(
              tr('Discount {0}% · {1}', [
                account.discountPercent,
                account.discountReason,
              ]),
              -account.discount,
              color: AppColors.success,
            ),
          const Divider(),
          row(tr('Total for the year'), account.total, bold: true),
          row(tr('Paid'), account.paid, color: AppColors.success),
        ],
      ),
    );
  }
}
