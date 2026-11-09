import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/grade_item_model.dart';
import '../models/subject_grades_model.dart';

/// Subject average with a bar. Tap to show every mark in that subject.
class SubjectGradesCard extends StatefulWidget {
  final SubjectGradesModel grades;

  const SubjectGradesCard({super.key, required this.grades});

  @override
  State<SubjectGradesCard> createState() => _SubjectGradesCardState();
}

class _SubjectGradesCardState extends State<SubjectGradesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final grades = widget.grades;
    final subject = grades.subject;
    final palette = context.palette;

    return AppCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Row(
            children: [
              IconBox(icon: subject.icon, color: subject.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: context.text.titleSmall),
                    Text(grades.label, style: context.text.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: grades.average / 100,
                        minHeight: 5,
                        color: grades.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                '${grades.average.round()}%',
                style: context.text.titleMedium?.copyWith(color: grades.color),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, color: palette.textMuted),
              ),
            ],
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        const Divider(),
                        for (final item in grades.items) _GradeItemRow(item),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _GradeItemRow extends StatelessWidget {
  final GradeItemModel item;

  const _GradeItemRow(this.item);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.text.bodyLarge),
                Text(
                  '${item.category} · ${DateFormatter.dayMonth(item.date)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${_format(item.score)} / ${_format(item.maxScore)}',
            style: context.text.titleSmall?.copyWith(
              color: GradeScale.colorFor(item.percentage),
            ),
          ),
        ],
      ),
    );
  }

  /// 9.0 → "9", 8.5 → "8.5"
  String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
