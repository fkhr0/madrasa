import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_summary_model.dart';
import '../../../core/l10n/language.dart';

/// Attendance rate plus one count per status.
class AttendanceSummaryCard extends StatelessWidget {
  final AttendanceSummaryModel summary;

  const AttendanceSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Attendance rate'), style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                summary.rate == null
                    ? '–'
                    : '${summary.rate!.toStringAsFixed(1)}%',
                style: context.text.headlineMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    tr('of {0} school days', [summary.totalDays]),
                    style: context.text.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _StackedBar(summary: summary),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final status in AttendanceStatus.values)
                Expanded(
                  child: _StatusCount(status: status, count: _countFor(status)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _countFor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return summary.present;
      case AttendanceStatus.late:
        return summary.late;
      case AttendanceStatus.absent:
        return summary.absent;
      case AttendanceStatus.excused:
        return summary.excused;
    }
  }
}

/// One bar split into coloured parts, one per status.
class _StackedBar extends StatelessWidget {
  final AttendanceSummaryModel summary;

  const _StackedBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final parts = [
      (summary.present, AttendanceStatus.present.color),
      (summary.late, AttendanceStatus.late.color),
      (summary.excused, AttendanceStatus.excused.color),
      (summary.absent, AttendanceStatus.absent.color),
    ].where((part) => part.$1 > 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final part in parts)
              Expanded(
                flex: part.$1,
                child: Container(
                  margin: const EdgeInsetsDirectional.only(end: 2),
                  color: part.$2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  final AttendanceStatus status;
  final int count;

  const _StatusCount({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                status.label,
                style: context.text.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('$count', style: context.text.titleMedium),
      ],
    );
  }
}
