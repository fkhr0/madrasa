import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../logic/year_result.dart';
import '../../../core/l10n/language.dart';

/// The year result of every subject: the parts so far (1st term, mid-year,
/// 2nd term, final) and, once complete, the final mark with pass / fail.
class YearResultCard extends StatelessWidget {
  final List<YearResultModel> results;

  const YearResultCard({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return AppCard(
        child: Text(
          tr('Appears after the first monthly exam scores are published.'),
          style: context.text.bodyMedium,
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, r) in results.indexed) ...[
            if (i > 0) const Divider(),
            _SubjectRow(result: r),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'Year work = (1st term + mid-year + 2nd term) ÷ 3. Result = (year work + final) ÷ 2. Pass from 50.',
            ),
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final YearResultModel result;

  const _SubjectRow({required this.result});

  static String _mark(double? n) => n == null ? '–' : '${n.round()}';

  @override
  Widget build(BuildContext context) {
    final mark = result.result;
    final soFar = result.yearWorkSoFar;
    final (value, label, color) = mark != null
        ? (
            _mark(mark),
            result.passed! ? tr('Pass') : tr('Fail'),
            result.passed! ? AppColors.success : AppColors.danger,
          )
        : soFar != null
        ? (_mark(soFar), tr('so far'), GradeScale.colorFor(soFar))
        : ('–', '', context.palette.textMuted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.subject.name, style: context.text.titleSmall),
                Text(
                  tr('1st term {0} · Mid-year {1} · 2nd term {2} · Final {3}', [
                    _mark(result.firstTerm),
                    _mark(result.midYear),
                    _mark(result.secondTerm),
                    _mark(result.finalExam),
                  ]),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: context.text.titleMedium?.copyWith(color: color),
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
