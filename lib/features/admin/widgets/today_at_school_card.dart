import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../models/school_stats_model.dart';
import '../../../core/l10n/language.dart';

/// Administrator's hero card: today's attendance across the school.
class TodayAtSchoolCard extends StatelessWidget {
  final SchoolStatsModel stats;

  const TodayAtSchoolCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.day),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.palette.hero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Today at school'),
              style: context.text.labelMedium?.copyWith(color: soft),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('{0}% present', [stats.attendanceRateToday.round()]),
              style: context.text.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.attendanceRateToday / 100,
                minHeight: 6,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('{0} present · {1} absent', [
                stats.presentToday,
                stats.absentToday,
              ]),
              style: context.text.bodySmall?.copyWith(color: soft),
            ),
          ],
        ),
      ),
    );
  }
}
