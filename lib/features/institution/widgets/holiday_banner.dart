import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../models/holiday_model.dart';
import '../../../core/l10n/language.dart';

/// Green card shown on top of the day list when the day is a holiday.
class HolidayBanner extends StatelessWidget {
  final HolidayModel holiday;

  const HolidayBanner({super.key, required this.holiday});

  @override
  Widget build(BuildContext context) {
    final range = holiday.end == null
        ? tr('No classes today')
        : tr('{0} – {1} · {2} days off', [
            DateFormatter.dayMonth(holiday.start),
            DateFormatter.dayMonth(holiday.lastDay),
            holiday.lengthInDays,
          ]);

    return AppCard(
      color: AppColors.success.withValues(alpha: 0.12),
      borderColor: Colors.transparent,
      child: Row(
        children: [
          Icon(holiday.type.icon, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(range, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
