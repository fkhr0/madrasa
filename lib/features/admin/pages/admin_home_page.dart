import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/quick_actions_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/greeting_header.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../activity/providers/activity_provider.dart';
import '../../activity/widgets/activity_tile.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_attention_section.dart';
import '../widgets/school_glance_row.dart';
import '../widgets/today_at_school_card.dart';
import '../../../core/l10n/language.dart';

/// Administrator's 10–30 second screen: today's attendance, the school in
/// numbers, what needs attention and what happened recently.
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(schoolStatsProvider);
    final activity = ref.watch(recentActivityProvider).valueOrNull ?? [];

    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: stats,
          onRetry: () => ref.invalidate(schoolStatsProvider),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              const GreetingHeader(),
              const SizedBox(height: AppSpacing.xl),
              TodayAtSchoolCard(stats: stats),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.school_outlined,
                      color: AppColors.subjectBlue,
                      value: '${stats.students}',
                      label: tr('Students'),
                      onTap: () => context.go(AppRoutes.work),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.co_present_outlined,
                      color: AppColors.subjectPurple,
                      value: '${stats.teachers}',
                      label: tr('Teachers'),
                      onTap: () => context.go(AppRoutes.work),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.groups_outlined,
                      color: AppColors.subjectTeal,
                      value: '${stats.classes}',
                      label: tr('Classes'),
                      onTap: () => context.go(AppRoutes.schedule),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SchoolGlanceRow(),
              const SizedBox(height: AppSpacing.lg),
              QuickActionsRow(
                actions: [
                  QuickAction(
                    icon: Icons.person_add_alt,
                    label: tr('Add person'),
                    color: AppColors.success,
                    onTap: () => context.push(AppRoutes.addPerson),
                  ),
                  QuickAction(
                    icon: Icons.campaign_outlined,
                    label: tr('Announce'),
                    color: AppColors.info,
                    onTap: () => context.push(AppRoutes.newAnnouncement),
                  ),
                  QuickAction(
                    icon: Icons.account_balance_wallet_outlined,
                    label: tr('Finance'),
                    color: AppColors.subjectTeal,
                    onTap: () => context.push(AppRoutes.finance),
                  ),
                  QuickAction(
                    icon: Icons.insights_outlined,
                    label: tr('Statistics'),
                    color: AppColors.subjectPurple,
                    onTap: () => context.push(AppRoutes.statistics),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAttentionSection(stats: stats),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                title: tr('Recent activity'),
                onSeeAll: () => context.push(AppRoutes.activity),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < activity.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                        ),
                      ActivityTile(item: activity[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
