import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../logic/trip_text.dart';
import '../models/trip_model.dart';
import '../../../core/l10n/language.dart';

/// Big status at the top of the bus page, with the route progress.
class TripStatusCard extends StatelessWidget {
  final TripModel trip;
  final DateTime now;
  final String? myStopId;

  const TripStatusCard({
    super.key,
    required this.trip,
    required this.now,
    this.myStopId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = describeTrip(trip, now, myStopId: myStopId);
    final running = trip.phase == TripPhase.onTheWay;

    return AppCard(
      color: running ? palette.primarySoft : null,
      borderColor: running ? Colors.transparent : null,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(icon: Icons.directions_bus, color: palette.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text.title, style: context.text.titleLarge),
                    Text(text.detail, style: context.text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (trip.phase != TripPhase.noTripToday) ...[
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: trip.progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              trip.delayMinutes > 0
                  ? tr('{0} · {1} min late', [
                      trip.direction.label,
                      trip.delayMinutes,
                    ])
                  : tr('{0} · on time', [trip.direction.label]),
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
