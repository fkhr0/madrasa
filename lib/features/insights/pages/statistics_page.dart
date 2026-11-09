import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/progress_bar_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../people/providers/people_provider.dart';
import '../logic/highlights.dart';
import '../models/insights_model.dart';
import '../providers/insights_provider.dart';
import '../widgets/day_columns_chart.dart';
import '../../../core/l10n/language.dart';

/// Administrator: the school in numbers, with the important parts
/// spelled out at the top.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(insightsPeriodProvider);
    final insights = ref.watch(insightsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Statistics'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<InsightsPeriod>(
                showSelectedIcon: false,
                segments: [
                  for (final p in InsightsPeriod.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {period},
                onSelectionChanged: (s) =>
                    ref.read(insightsPeriodProvider.notifier).state = s.first,
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: insights,
              onRetry: () => ref.invalidate(insightsProvider),
              data: (data) => _StatisticsBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsBody extends ConsumerWidget {
  final InsightsModel data;

  const _StatisticsBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String pct(double rate) => '${(rate * 100).round()}%';
    int count(UserRole role) =>
        ref.watch(peopleByRoleProvider(role)).valueOrNull?.length ?? 0;
    final change = data.attendanceChange;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        _Highlights(highlights: highlightsFor(data)),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: tr('Attendance')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pct(data.attendanceRate),
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      tr('{0} {1} pts', [
                        change >= 0 ? '▲' : '▼',
                        change.abs().toStringAsFixed(1),
                      ]),
                      style: context.text.labelMedium?.copyWith(
                        color: change >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              Text(tr('present on average'), style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              DayColumnsChart(days: data.attendanceByDay),
              const Divider(height: AppSpacing.xl),
              for (final c in data.attendanceByClass)
                ProgressBarRow(
                  label: c.label,
                  value: pct(c.value),
                  fraction: c.value,
                  color: c.value < 0.88 ? AppColors.warning : AppColors.success,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: tr('Learning')),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.grade_outlined,
                color: GradeScale.colorFor(data.averageGrade),
                value: data.averageGrade.toStringAsFixed(1),
                label: tr('Average /100'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.verified_outlined,
                color: AppColors.success,
                value: pct(data.passRate),
                label: tr('Passing'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.assignment_turned_in_outlined,
                color: AppColors.info,
                value: pct(data.submissionRate),
                label: tr('Homework in'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              for (final s in data.gradeBySubject)
                ProgressBarRow(
                  label: s.label,
                  value: '${s.value.round()}',
                  fraction: s.value / 100,
                  color: GradeScale.colorFor(s.value),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: tr('Buses')),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.directions_bus_outlined,
                color: AppColors.subjectAmber,
                value: '${data.tripsDone}',
                label: tr('Trips'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                color: AppColors.success,
                value: pct(data.onTimeRate),
                label: tr('On time'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.hourglass_bottom,
                color: AppColors.warning,
                value: tr('{0} min', [data.averageDelayMinutes]),
                label: tr('Avg. delay'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: tr('People')),
        AppCard(
          child: Column(
            children: [
              for (final role in [
                UserRole.student,
                UserRole.teacher,
                UserRole.parent,
                UserRole.driver,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${role.label}s',
                          style: context.text.bodyMedium,
                        ),
                      ),
                      Text('${count(role)}', style: context.text.titleSmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Highlights extends StatelessWidget {
  final List<Highlight> highlights;

  const _Highlights({required this.highlights});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      color: palette.primarySoft,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(tr('What stands out'), style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final h in highlights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    h.isGood ? Icons.trending_up : Icons.error_outline,
                    size: 18,
                    color: h.isGood ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(h.text, style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
