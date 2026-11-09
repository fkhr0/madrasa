import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../models/academic_year_model.dart';
import '../../../core/l10n/language.dart';

/// "2026–2027 · First semester · Week 7 of 38" with a progress bar.
class YearProgressCard extends StatelessWidget {
  final AcademicYearModel year;
  final DateTime day;

  const YearProgressCard({super.key, required this.year, required this.day});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final week = year.weekNumber(day).clamp(1, year.totalWeeks);
    final holiday = year.holidayOn(day);
    final term = year.termOn(day);

    final status = holiday?.name ?? term?.name ?? tr('Between terms');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${year.name} · $status',
                  style: context.text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                tr('Week {0} of {1}', [week, year.totalWeeks]),
                style: context.text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: week / year.totalWeeks,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
