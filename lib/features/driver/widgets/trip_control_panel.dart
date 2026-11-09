import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/phone_call.dart';
import '../../institution/providers/institution_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../transport/models/bus_route_model.dart';
import '../../transport/models/route_student_model.dart';
import '../../transport/models/trip_model.dart';
import '../../transport/providers/transport_provider.dart';
import '../../transport/repo/transport_repository.dart';
import '../../transport/widgets/bus_map.dart';
import 'boarding_list.dart';
import 'delay_sheet.dart';
import 'end_early_dialog.dart';
import 'gps_reporter.dart';
import '../../../core/l10n/language.dart';

/// During a trip: the map, where the bus is, one big next-step button,
/// and the students to tick off at the current stop.
class TripControlPanel extends ConsumerWidget {
  final BusRouteModel route;
  final TripModel trip;
  final List<RouteStudentModel> students;
  final DateTime now;

  const TripControlPanel({
    super.key,
    required this.route,
    required this.trip,
    required this.students,
    required this.now,
  });

  /// Runs a driver action; the server's refusal is shown, not lost.
  static Future<void> _run(BuildContext context, Future<void> action) async {
    try {
      await action;
    } on TransportException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  /// Who gets on or off at the stop the bus is standing at.
  List<RouteStudentModel> _studentsHere() {
    if (trip.lastReachedIndex < 0) return const [];
    final stop = trip.stops[trip.lastReachedIndex];
    final atSchool = stop.isSchool;

    if (trip.direction == TripDirection.toHome && atSchool) return students;
    if (atSchool) return const [];

    return students.where((s) => s.stopId == stop.id).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(transportActionsProvider);
    // Before the first stop the bus is still on its way there.
    final current =
        trip.stops[trip.lastReachedIndex.clamp(0, trip.stops.length - 1)];
    final nextIndex = trip.nextStopIndex;
    final finished = trip.phase == TripPhase.arrived;
    final onBoard = students
        .where((s) => trip.statusOf(s) == BoardingStatus.onBoard)
        .length;

    final String headline;
    final String detail;
    if (finished) {
      headline = trip.direction == TripDirection.toSchool
          ? tr('Arrived at school')
          : tr('Last stop reached');
      detail = tr('You can end the trip');
    } else if (trip.isAtStop) {
      headline = tr('At {0}', [current.name]);
      detail = tr('Stop {0} of {1} · {2}', [
        trip.lastReachedIndex + 1,
        trip.stops.length,
        current.landmark,
      ]);
    } else {
      final seconds = trip.expectedAt(nextIndex!).difference(now).inSeconds;
      headline = tr('Driving to {0}', [trip.stops[nextIndex].name]);
      detail = seconds <= 0
          ? tr('Arriving now')
          : seconds < 90
          ? tr('Arriving in {0} s', [seconds])
          : tr('Arriving in about {0} min', [(seconds / 60).round()]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusMap(stops: trip.stops, trip: trip, height: 220),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusBadge(
                    label: tr('LIVE · {0}', [trip.direction.label]),
                    color: AppColors.success,
                    icon: Icons.sensors,
                  ),
                  const Spacer(),
                  Text(
                    tr('{0} on board', [onBoard]),
                    style: context.text.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(headline, style: context.text.headlineSmall),
              Text(detail, style: context.text.bodyMedium),
              if (trip.delayMinutes > 0)
                Text(
                  tr('Reported {0} min late · {1}', [
                    trip.delayMinutes,
                    tr(trip.delayReason ?? ''),
                  ]),
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              // Test mode without a server drives the bus by itself.
              if (!finished && AppConfig.useApi) ...[
                const SizedBox(height: AppSpacing.sm),
                GpsReporter(routeId: route.id),
              ],
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: trip.progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // One clear next step.
              if (finished)
                FilledButton.icon(
                  onPressed: () => _run(context, actions.endTrip(route.id)),
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(tr('End trip')),
                )
              else if (trip.isAtStop)
                FilledButton.icon(
                  onPressed: () => _run(context, actions.leaveStop(route.id)),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(tr('Leave {0}', [current.name])),
                )
              else
                // GPS moves the bus on by itself; this is for when it can't.
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _run(context, actions.arriveAtStop(route.id)),
                  icon: const Icon(Icons.place_outlined),
                  label: Text(
                    tr('Arrived at {0}', [trip.stops[nextIndex!].name]),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: finished
                          ? null
                          : () => showDelaySheet(context, route.id),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(tr('Delay')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => callPhone(
                        context,
                        ref.read(institutionProvider).valueOrNull?.phone ?? '',
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: Text(tr('School')),
                    ),
                  ),
                ],
              ),
              if (!finished)
                TextButton(
                  onPressed: () async {
                    final reason = await showEndEarlyDialog(context);
                    if (reason != null && context.mounted) {
                      await _run(
                        context,
                        actions.endTrip(route.id, earlyReason: reason),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: Text(tr('End trip early')),
                ),
            ],
          ),
        ),
        if (trip.isAtStop && !finished) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: trip.direction == TripDirection.toHome && current.isSchool
                ? tr('Students boarding at school')
                : tr('Students at {0}', [current.name]),
          ),
          BoardingList(
            routeId: route.id,
            trip: trip,
            students: _studentsHere(),
          ),
        ],
      ],
    );
  }
}
