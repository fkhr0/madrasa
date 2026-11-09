import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/student_account_model.dart';
import '../../../core/l10n/language.dart';

/// The year's installments with how much of each is paid.
class InstallmentList extends StatelessWidget {
  final StudentAccountModel account;
  final DateTime now;

  const InstallmentList({super.key, required this.account, required this.now});

  @override
  Widget build(BuildContext context) {
    final installments = account.installments;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < installments.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          installments[i].name,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          tr('Due {0}', [
                            DateFormatter.fullDate(installments[i].dueDate),
                          ]),
                          style: context.text.bodySmall,
                        ),
                        if (account.installmentStatus(i, now) !=
                                InstallmentStatus.paid &&
                            account.coveredOf(i) > 0)
                          Text(
                            tr('{0} paid so far', [
                              MoneyFormatter.iqd(account.coveredOf(i)),
                            ]),
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        MoneyFormatter.iqd(installments[i].amount),
                        style: context.text.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StatusBadge(
                        label: account.installmentStatus(i, now).label,
                        color: account.installmentStatus(i, now).color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
