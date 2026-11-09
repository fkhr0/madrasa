import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../finance/providers/finance_provider.dart';
import '../../transport/models/trip_model.dart';
import '../../transport/providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Two live numbers for the administrator: fees collected and buses on
/// the road. Each opens its full page.
class SchoolGlanceRow extends ConsumerWidget {
  const SchoolGlanceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeSummaryProvider).valueOrNull;
    final routes = ref.watch(busRoutesProvider).valueOrNull ?? [];
    final running = routes.where((r) {
      final trip = ref.watch(tripProvider(r.id)).valueOrNull;
      return trip != null && trip.phase == TripPhase.onTheWay;
    }).length;

    return Row(
      children: [
        Expanded(
          child: _GlanceCard(
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
            title: finance == null
                ? '…'
                : tr('{0}% collected', [
                    (finance.collectionRate * 100).round(),
                  ]),
            subtitle: finance == null || finance.overdueFamilies == 0
                ? tr('School fees')
                : tr('{0} families overdue', [finance.overdueFamilies]),
            onTap: () => context.push(AppRoutes.finance),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _GlanceCard(
            icon: Icons.directions_bus_outlined,
            color: AppColors.subjectAmber,
            title: tr('{0} of {1} buses', [running, routes.length]),
            subtitle: tr('on the road now'),
            onTap: () => context.push(AppRoutes.transport),
          ),
        ),
      ],
    );
  }
}

class _GlanceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GlanceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBox(icon: icon, color: color, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
