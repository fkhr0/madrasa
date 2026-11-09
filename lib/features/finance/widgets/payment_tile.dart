import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/payment_model.dart';

/// A payment with its receipt number.
class PaymentTile extends StatelessWidget {
  final PaymentModel payment;

  /// Shown above the details, e.g. the student's name in a school-wide list.
  final String? title;

  /// The office taps a payment to void it.
  final VoidCallback? onTap;

  const PaymentTile({super.key, required this.payment, this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            IconBox(
              icon: payment.method.icon,
              color: AppColors.success,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? payment.method.label,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    '${DateFormatter.dayMonth(payment.date)} · '
                    '${payment.receiptNumber}'
                    '${title != null ? ' · ${payment.method.label}' : ''}',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '+${MoneyFormatter.grouped(payment.amount)}',
              style: context.text.labelLarge?.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
