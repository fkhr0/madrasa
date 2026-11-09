import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/bus_route_model.dart';
import '../models/trip_model.dart';
import '../providers/transport_provider.dart';
import '../widgets/bus_info_card.dart';
import '../widgets/bus_map.dart';
import '../widgets/route_timeline.dart';
import '../widgets/trip_status_card.dart';
import '../../../core/l10n/language.dart';

/// A whole bus line: map, live status, stops and staff.
/// Administrators also get the tools to change it.
/// Without [routeId] it is the signed-in driver's Route tab.
class RouteDetailsPage extends ConsumerWidget {
  /// Null = the signed-in driver's own line.
  final String? routeId;

  const RouteDetailsPage({super.key, this.routeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = routeId;
    final AsyncValue<BusRouteModel?> route = id == null
        ? ref.watch(driverRouteProvider)
        : ref.watch(busRouteProvider(id));
    final isAdmin = ref.watch(currentUserProvider).role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(route.valueOrNull?.name ?? tr('Route')),
        actions: [
          if (isAdmin && id != null)
            IconButton(
              tooltip: tr('Edit line'),
              onPressed: () => context.push(AppRoutes.editRoute(id)),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AsyncValueView(
        value: route,
        data: (route) {
          if (route == null) {
            return EmptyState(
              icon: Icons.route_outlined,
              title: id == null ? tr('No bus assigned') : tr('Line not found'),
              message: id == null
                  ? tr('The school office assigns you to a line.')
                  : null,
            );
          }

          return _RouteBody(route: route, isAdmin: isAdmin);
        },
      ),
    );
  }
}

class _RouteBody extends ConsumerWidget {
  final BusRouteModel route;
  final bool isAdmin;

  const _RouteBody({required this.route, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(route.id)).valueOrNull;
    final now = ref.watch(nowProvider);
    final hasTrip = trip != null && trip.phase != TripPhase.noTripToday;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        BusMap(
          stops: hasTrip ? trip.stops : route.stops,
          trip: trip,
          road: route.roadFor(TripDirection.toSchool),
        ),
        const SizedBox(height: AppSpacing.md),
        if (trip != null) TripStatusCard(trip: trip, now: now),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.place_outlined,
                  iconColor: AppColors.subjectBlue,
                  title: tr('Stops and times'),
                  subtitle: tr('{0} pick-up stops', [route.pickUpStops.length]),
                  onTap: () => context.push(AppRoutes.routeStops(route.id)),
                ),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                MenuTile(
                  icon: Icons.groups_outlined,
                  iconColor: AppColors.subjectTeal,
                  title: tr('Riders'),
                  subtitle: tr('{0} of {1} seats{2}', [
                    route.studentCount,
                    route.capacity,
                    route.isFull ? tr(' · full') : '',
                  ]),
                  onTap: () => context.push(AppRoutes.routeStudents(route.id)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: hasTrip ? trip.direction.label : tr('Stops')),
        RouteTimeline(trip: hasTrip ? trip : _timetable(route, now)),
        SectionHeader(title: tr('Bus and staff')),
        BusInfoCard(route: route),
      ],
    );
  }

  /// The morning timetable, for days without a trip.
  static TripModel _timetable(BusRouteModel route, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);

    return TripModel(
      direction: TripDirection.toSchool,
      phase: TripPhase.notStarted,
      stops: route.stops,
      plannedTimes: [
        for (final s in route.stops)
          day.add(Duration(minutes: s.morningMinute)),
      ],
      lastReachedIndex: -1,
      updatedAt: now,
    );
  }
}
