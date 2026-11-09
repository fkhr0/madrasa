import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../academics/providers/academics_provider.dart';
import '../../auth/models/user_model.dart';
import '../../finance/models/student_account_model.dart';
import '../../finance/providers/finance_provider.dart';
import '../../people/providers/people_provider.dart';
import '../../transport/providers/transport_provider.dart';
import '../models/school_stats_model.dart';
import '../../../core/l10n/language.dart';

/// What the administrator should look at today.
class AdminAttentionSection extends ConsumerWidget {
  final SchoolStatsModel stats;

  const AdminAttentionSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unassigned = ref.watch(unassignedSubjectsCountProvider);
    final inactive = [
      for (final role in UserRole.values)
        ...?ref.watch(peopleByRoleProvider(role)).valueOrNull,
    ].where((u) => !u.isActive).length;

    final missing = stats.classesMissingAttendance;
    final overdueFamilies =
        ref.watch(financeSummaryProvider).valueOrNull?.overdueFamilies ?? 0;
    final routes = ref.watch(busRoutesProvider).valueOrNull ?? [];
    final lateBuses = routes.where((r) {
      final trip = ref.watch(tripProvider(r.id)).valueOrNull;
      return trip != null && trip.isLive && trip.delayMinutes > 0;
    });

    final items = [
      if (missing.isNotEmpty)
        _Item(
          icon: Icons.fact_check_outlined,
          color: AppColors.danger,
          title: tr('Attendance not taken'),
          subtitle: missing.join(', '),
        ),
      if (unassigned > 0)
        _Item(
          icon: Icons.person_search_outlined,
          color: AppColors.warning,
          title: tr('{0} subjects without a teacher', [unassigned]),
          subtitle: tr('Assign them in Academic → Classes'),
          onTap: () => context.go(AppRoutes.schedule),
        ),
      if (overdueFamilies > 0)
        _Item(
          icon: Icons.payments_outlined,
          color: AppColors.danger,
          title: tr('{0} families behind on fees', [overdueFamilies]),
          subtitle: tr('Open Finance to remind them'),
          onTap: () {
            ref.read(accountFilterProvider.notifier).state =
                AccountStatus.overdue;
            context.push(AppRoutes.finance);
          },
        ),
      for (final route in routes.where((r) => !r.hasDriver))
        _Item(
          icon: Icons.no_transfer_outlined,
          color: AppColors.warning,
          title: tr('Bus {0} has no driver', [route.busNumber]),
          subtitle: route.name,
          onTap: () => context.push(AppRoutes.editRoute(route.id)),
        ),
      for (final route in lateBuses)
        _Item(
          icon: Icons.schedule,
          color: AppColors.warning,
          title: tr('Bus {0} is running late', [route.busNumber]),
          subtitle: route.name,
          onTap: () => context.push(AppRoutes.busRoute(route.id)),
        ),
      if (inactive > 0)
        _Item(
          icon: Icons.person_off_outlined,
          color: AppColors.neutral,
          title: tr('{0} inactive accounts', [inactive]),
          subtitle: tr('They cannot sign in'),
          onTap: () => context.go(AppRoutes.work),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: tr('Needs attention')),
        if (items.isEmpty)
          Text(tr('Everything is in order.'), style: context.text.bodyMedium),
        for (final item in items) ...[
          item,
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Item({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBox(icon: icon, color: color, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
