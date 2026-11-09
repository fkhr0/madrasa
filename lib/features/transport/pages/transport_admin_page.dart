import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../logic/trip_text.dart';
import '../models/bus_route_model.dart';
import '../models/trip_model.dart';
import '../providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: every bus line with its live status, and the tools to
/// manage lines, drivers, stops, riders and trip rules.
class TransportAdminPage extends ConsumerWidget {
  const TransportAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(busRoutesProvider);
    final settings = ref.watch(transportSettingsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Transport'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newRoute),
        icon: const Icon(Icons.add_road),
        label: Text(tr('New line')),
      ),
      body: AsyncValueView(
        value: routes,
        onRetry: () => ref.invalidate(busRoutesProvider),
        data: (routes) {
          final trips = [
            for (final r in routes) ref.watch(tripProvider(r.id)).valueOrNull,
          ];
          final running = trips
              .where((t) => t != null && t.phase == TripPhase.onTheWay)
              .length;
          final riders = routes.fold(0, (sum, r) => sum + r.studentCount);
          final noDriver = routes.where((r) => !r.hasDriver).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              96, // room for the button
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.directions_bus_outlined,
                      color: AppColors.subjectAmber,
                      value: '${routes.length}',
                      label: tr('Lines'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.near_me_outlined,
                      color: AppColors.success,
                      value: '$running',
                      label: tr('On the road'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.groups_outlined,
                      color: AppColors.subjectBlue,
                      value: '$riders',
                      label: tr('Riders'),
                    ),
                  ),
                ],
              ),
              if (noDriver > 0) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderColor: Colors.transparent,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          noDriver == 1
                              ? tr(
                                  '1 line has no driver. Open it to assign one.',
                                )
                              : tr('{0} lines have no driver.', [noDriver]),
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: MenuTile(
                  icon: Icons.rule,
                  iconColor: AppColors.subjectPurple,
                  title: tr('Trip rules'),
                  subtitle: settings == null
                      ? null
                      : tr('Start {0} min before · {1}', [
                          settings.opensBeforeMinutes,
                          settings.testMode
                              ? tr('test mode on')
                              : tr('test mode off'),
                        ]),
                  onTap: () => context.push(AppRoutes.transportSettings),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: tr('Lines')),
              if (routes.isEmpty)
                EmptyState(
                  icon: Icons.route_outlined,
                  title: tr('No bus lines yet'),
                  message: tr('Add the first line with the button below.'),
                )
              else
                for (final route in routes) ...[
                  _RouteCard(route: route),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  final BusRouteModel route;

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(route.id)).valueOrNull;
    final now = ref.watch(nowProvider);
    final status = trip == null ? null : describeTrip(trip, now);
    final running = trip?.phase == TripPhase.onTheWay;
    final late = trip != null && trip.delayMinutes > 0;

    return AppCard(
      onTap: () => context.push(AppRoutes.busRoute(route.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: Icons.directions_bus,
                color: running ? AppColors.success : context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Bus {0} · {1}', [route.busNumber, route.name]),
                      style: context.text.titleSmall,
                    ),
                    Text(
                      tr('{0} · {1} stops', [
                        route.hasDriver ? route.driverName : tr('No driver'),
                        route.pickUpStops.length,
                      ]),
                      style: context.text.bodySmall?.copyWith(
                        color: route.hasDriver ? null : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: '${route.studentCount}/${route.capacity}',
                color: route.isFull ? AppColors.warning : AppColors.info,
                icon: Icons.people_outline,
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  running ? Icons.near_me : Icons.schedule,
                  size: 16,
                  color: late
                      ? AppColors.warning
                      : running
                      ? AppColors.success
                      : context.palette.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${status.title} · ${status.detail}',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trip != null && trip.isLive)
                  StatusBadge(label: tr('LIVE'), color: AppColors.success),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
