import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/student_account_model.dart';
import '../../../core/l10n/language.dart';

/// One family's account in the Finance list.
class AccountTile extends StatelessWidget {
  final StudentAccountModel account;
  final DateTime now;

  const AccountTile({super.key, required this.account, required this.now});

  @override
  Widget build(BuildContext context) {
    final status = account.status(now);
    final overdue = account.overdueAmount(now);

    final String line;
    if (status == AccountStatus.paidInFull) {
      line = tr('Paid {0}', [MoneyFormatter.iqd(account.paid)]);
    } else if (overdue > 0) {
      line = tr('{0} overdue', [MoneyFormatter.iqd(overdue)]);
    } else {
      line = tr('Balance {0}', [MoneyFormatter.iqd(account.balance)]);
    }

    return AppCard(
      onTap: () => context.push(AppRoutes.studentAccount(account.studentId)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          UserAvatar(name: account.studentName, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.studentName, style: context.text.titleSmall),
                Text(
                  '${account.className} · $line',
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(label: status.label, color: status.color),
        ],
      ),
    );
  }
}
