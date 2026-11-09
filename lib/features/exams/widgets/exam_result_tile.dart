import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/exam_model.dart';
import '../../../core/l10n/language.dart';

/// A past exam with its result (or "Results soon").
class ExamResultTile extends StatelessWidget {
  final ExamModel exam;

  const ExamResultTile({super.key, required this.exam});

  String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  Widget build(BuildContext context) {
    final subject = exam.subject;

    return AppCard(
      child: Row(
        children: [
          IconBox(icon: subject.icon, color: subject.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: context.text.titleSmall),
                Text(
                  '${exam.type.label} · ${DateFormatter.dayMonth(exam.start)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (exam.hasResult)
            Text(
              '${_format(exam.score!)} / ${_format(exam.maxScore!)}',
              style: context.text.titleMedium?.copyWith(
                color: GradeScale.colorFor(exam.percentage),
              ),
            )
          else
            Text(
              tr('Results soon'),
              style: context.text.bodySmall?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
