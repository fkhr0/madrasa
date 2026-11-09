import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../../transport/logic/trip_rules.dart';
import '../../transport/logic/trip_text.dart';
import '../../transport/models/bus_route_model.dart';
import '../../transport/models/route_student_model.dart';
import '../../transport/models/trip_model.dart';
import '../../transport/providers/transport_provider.dart';
import '../../transport/repo/transport_repository.dart';
import '../../../core/l10n/language.dart';

/// Before a trip: today's two trips, whether each can start, and one
/// main button for the trip that fits the time of day.
class TripStartCard extends ConsumerWidget {
  final BusRouteModel route;
  final List<RouteStudentModel> students;
  final DateTime now;

  const TripStartCard({
    super.key,
    required this.route,
    required this.students,
    required this.now,
  });

  String _time(int minuteOfDay) => DateFormatter.time(
    DateTime(now.year, now.month, now.day).add(Duration(minutes: minuteOfDay)),
  );

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    TripDirection direction,
  ) async {
    try {
      await ref.read(transportActionsProvider).startTrip(route.id, direction);
    } on TransportException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripAvailabilityProvider(route.id));
    if (trips.isEmpty) return const SizedBox.shrink();

    final main = suggestedTrip(trips);
    final first = route.stops.first;
    final school = route.stops.last;
    final notRiding = students.where((s) => s.notRidingToday).length;

    String detail(TripDirection direction) =>
        direction == TripDirection.toSchool
        ? tr('{0} {1} → {2} school', [
            _time(first.morningMinute),
            first.name,
            _time(school.morningMinute),
          ])
        : tr('{0} school → {1} {2}', [
            _time(school.afternoonMinute),
            _time(first.afternoonMinute),
            first.name,
          ]);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Today\'s trips'), style: context.text.titleMedium),
          Text(
            tr('{0} riding{1}', [
              students.length - notRiding,
              notRiding > 0 ? tr(' · {0} not riding today', [notRiding]) : '',
            ]),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final trip in trips) ...[
            _TripRow(
              trip: trip,
              detail: detail(trip.direction),
              status: tripAvailabilityText(trip, now),
              highlighted: identical(trip, main),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: main.canStart
                ? () => _start(context, ref, main.direction)
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(tr('Start {0}', [main.direction.label.toLowerCase()])),
          ),
          // The other trip, only when it can start too (test mode).
          for (final other in trips)
            if (!identical(other, main) && other.canStart) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _start(context, ref, other.direction),
                child: Text(
                  tr('Start {0}', [other.direction.label.toLowerCase()]),
                ),
              ),
            ],
          if (trips.any((t) => t.startsByTestMode)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              tr(
                'Test mode is on: trips can start outside their times. The administrator turns it off in Transport › Trip rules.',
              ),
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final TripAvailability trip;
  final String detail;
  final String status;
  final bool highlighted;

  const _TripRow({
    required this.trip,
    required this.detail,
    required this.status,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final morning = trip.direction == TripDirection.toSchool;
    final color = switch (trip.block) {
      TripBlock.none => AppColors.success,
      TripBlock.alreadyDone => AppColors.info,
      TripBlock.tooEarly => palette.primary,
      _ => AppColors.neutral,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlighted ? palette.primarySoft : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? palette.primary : palette.border,
        ),
      ),
      child: Row(
        children: [
          IconBox(
            icon: morning
                ? Icons.wb_sunny_outlined
                : Icons.nights_stay_outlined,
            color: palette.primary,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.direction.label, style: context.text.titleSmall),
                Text(detail, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                StatusBadge(
                  label: status,
                  color: color,
                  icon: trip.isOpen
                      ? Icons.check_circle_outline
                      : Icons.schedule,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
