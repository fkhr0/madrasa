import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/trip_model.dart';
import '../../../core/l10n/language.dart';

/// The stops of the current trip as a vertical line:
/// passed stops are filled, the bus sits after the last reached stop,
/// and the student's stop is marked.
class RouteTimeline extends StatelessWidget {
  final TripModel trip;
  final String? myStopId;

  const RouteTimeline({super.key, required this.trip, this.myStopId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < trip.stops.length; i++)
          _StopRow(
            trip: trip,
            index: i,
            isMine: trip.stops[i].id == myStopId,
            isLast: i == trip.stops.length - 1,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final TripModel trip;
  final int index;
  final bool isMine;
  final bool isLast;

  const _StopRow({
    required this.trip,
    required this.index,
    required this.isMine,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stop = trip.stops[index];
    final passed = trip.hasPassed(index);

    // The bus is drawn on the line right after the last stop it reached.
    final busHere =
        trip.lastReachedIndex == index && trip.phase == TripPhase.onTheWay;

    final dotColor = passed ? palette.primary : palette.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                DateFormatter.time(trip.expectedAt(index)),
                style: context.text.titleSmall?.copyWith(
                  color: passed ? palette.textMuted : palette.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: isMine ? 16 : 12,
                  height: isMine ? 16 : 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed ? dotColor : palette.card,
                    border: Border.all(
                      color: isMine ? palette.primary : dotColor,
                      width: 2.5,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 2.5,
                          color: trip.hasPassed(index + 1)
                              ? palette.primary
                              : palette.border,
                        ),
                        if (busHere)
                          Icon(
                            Icons.directions_bus,
                            size: 20,
                            color: palette.primary,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          stop.name,
                          style: context.text.titleSmall?.copyWith(
                            color: passed ? palette.textMuted : null,
                          ),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(
                          label: tr('Your stop'),
                          color: palette.primary,
                        ),
                      ],
                    ],
                  ),
                  Text(stop.landmark, style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
