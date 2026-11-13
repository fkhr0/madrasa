import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/route_student_model.dart';
import '../models/student_transport_model.dart';
import '../models/trip_model.dart';
import '../providers/transport_provider.dart';
import '../widgets/bus_info_card.dart';
import '../widgets/bus_map.dart';
import '../widgets/family_home_card.dart';
import '../widgets/route_timeline.dart';
import '../widgets/trip_status_card.dart';
import '../../../core/l10n/language.dart';

/// Student / parent: where the bus is, when it reaches their stop,
/// and (for parents) whether the child is on board.
class BusPage extends ConsumerWidget {
  const BusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(myTransportProvider);
    final child = ref.watch(activeStudentProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('School bus'))),
      body: AsyncValueView(
        value: transport,
        onRetry: () => ref.invalidate(myTransportProvider),
        data: (transport) {
          if (transport == null) {
            final isParent =
                ref.watch(currentUserProvider).role == UserRole.parent;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                EmptyState(
                  icon: Icons.directions_walk,
                  title: tr('No school bus'),
                  message: tr(
                    '{0} is not registered for school transport. Contact the school office to join a line.',
                    [child?.firstName ?? tr('This student')],
                  ),
                ),
                // Sharing the home first lets the school plan a stop there.
                if (isParent && child != null)
                  FamilyHomeCard(
                    studentId: child.id,
                    firstName: child.firstName,
                  ),
              ],
            );
          }

          return _Content(transport: transport);
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final StudentTransportModel transport;

  const _Content({required this.transport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(transport.route.id));
    final isParent = ref.watch(currentUserProvider).role == UserRole.parent;
    final child = ref.watch(activeStudentProvider);

    return AsyncValueView(
      value: trip,
      data: (trip) {
        final now = trip.updatedAt.isAfter(ref.watch(nowProvider))
            ? trip.updatedAt
            : ref.watch(nowProvider);
        final hasTrip = trip.phase != TripPhase.noTripToday;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            BusMap(
              stops: hasTrip ? trip.stops : transport.route.stops,
              trip: trip,
              myStopId: transport.stopId,
              road: transport.route.roadToSchool,
            ),
            const SizedBox(height: AppSpacing.md),
            TripStatusCard(trip: trip, now: now, myStopId: transport.stopId),

            if (child != null && trip.isLive) ...[
              const SizedBox(height: AppSpacing.md),
              _BoardingStatusCard(
                name: child.firstName,
                status: trip.statusFor(
                  studentId: child.id,
                  stopId: transport.stopId,
                  notRidingToday: transport.notRidingToday,
                ),
              ),
            ],

            if (isParent && child != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('{0} won\'t ride today', [child.firstName])),
                  subtitle: Text(tr('The driver will not wait at the stop')),
                  value: transport.notRidingToday,
                  onChanged: (v) => ref
                      .read(transportActionsProvider)
                      .setNotRidingToday(child.id, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FamilyHomeCard(studentId: child.id, firstName: child.firstName),
            ],

            const SizedBox(height: AppSpacing.xl),
            if (hasTrip) ...[
              SectionHeader(title: trip.direction.label),
              RouteTimeline(trip: trip, myStopId: transport.stopId),
            ],

            SectionHeader(title: tr('Bus and staff')),
            BusInfoCard(route: transport.route),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  trip.isLive ? Icons.sensors : Icons.info_outline,
                  size: 16,
                  color: trip.isLive
                      ? AppColors.success
                      : context.palette.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trip.isLive
                        ? tr('Live: the driver is reporting this trip.')
                        : tr(
                            'Following the timetable until the driver starts the trip.',
                          ),
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BoardingStatusCard extends StatelessWidget {
  final String name;
  final BoardingStatus status;

  const _BoardingStatusCard({required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      BoardingStatus.waiting => tr('{0} is waiting for the bus', [name]),
      BoardingStatus.onBoard => tr('{0} is on the bus', [name]),
      BoardingStatus.droppedOff => tr('{0} got off the bus', [name]),
      BoardingStatus.absent => tr('{0} was not at the stop', [name]),
      BoardingStatus.notRiding => tr('{0} is not riding today', [name]),
    };

    return AppCard(
      color: status.color.withValues(alpha: 0.1),
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBox(icon: Icons.person_pin_circle_outlined, color: status.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.text.titleSmall)),
        ],
      ),
    );
  }
}
