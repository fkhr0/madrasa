import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../dashboard/widgets/greeting_header.dart';
import '../../transport/providers/transport_provider.dart';
import '../widgets/trip_control_panel.dart';
import '../widgets/trip_start_card.dart';
import '../../../core/l10n/language.dart';

/// Driver's home: start a trip, then drive it stop by stop.
/// Big buttons and few words, the driver looks at it between stops.
class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(driverRouteProvider);

    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: route,
          onRetry: () => ref.invalidate(driverRouteProvider),
          data: (route) {
            if (route == null) {
              return EmptyState(
                icon: Icons.directions_bus_outlined,
                title: tr('No bus assigned'),
                message: tr('The school office assigns you to a line.'),
              );
            }

            final trip = ref.watch(tripProvider(route.id)).valueOrNull;
            final students =
                ref.watch(routeStudentsProvider(route.id)).valueOrNull ?? [];
            // Live trips tick every second, so use the trip's own time.
            final DateTime clock = ref.watch(nowProvider);
            final now = trip?.updatedAt ?? clock;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                const GreetingHeader(),
                const SizedBox(height: AppSpacing.xl),
                if (trip != null && trip.isLive)
                  TripControlPanel(
                    route: route,
                    trip: trip,
                    students: students,
                    now: now,
                  )
                else
                  TripStartCard(route: route, students: students, now: now),
              ],
            );
          },
        ),
      ),
    );
  }
}
