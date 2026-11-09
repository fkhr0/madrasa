import '../../../core/utils/date_formatter.dart';
import '../models/trip_model.dart';
import 'trip_rules.dart';
import '../../../core/l10n/language.dart';

/// Turns a trip into two lines a person can read at a glance.
/// [myStopId] is the student's stop (null for drivers and administrators).
({String title, String detail}) describeTrip(
  TripModel trip,
  DateTime now, {
  String? myStopId,
}) {
  if (trip.phase == TripPhase.noTripToday) {
    return (
      title: tr('No bus today'),
      detail: tr('No school trips on this day'),
    );
  }

  final toSchool = trip.direction == TripDirection.toSchool;
  final myIndex = myStopId == null ? -1 : trip.indexOf(myStopId);
  final hasMyStop = myIndex != -1;
  final late = trip.delayMinutes > 0
      ? tr(' · {0} min late', [trip.delayMinutes])
      : '';
  String at(int i) => DateFormatter.time(trip.expectedAt(i));

  switch (trip.phase) {
    case TripPhase.notStarted:
      final firstStop = toSchool ? tr('Bus leaves') : tr('Leaves school');
      return (
        title: tr('{0} at {1}', [firstStop, at(0)]),
        detail: !hasMyStop
            ? trip.direction.label
            : toSchool
            ? tr('Picks you up at {0} · {1}', [
                at(myIndex),
                trip.stops[myIndex].name,
              ])
            : tr('Drops you at {0} · {1}', [
                at(myIndex),
                trip.stops[myIndex].name,
              ]),
      );

    case TripPhase.onTheWay:
      final current = trip.lastReachedIndex < 0
          ? ''
          : trip.stops[trip.lastReachedIndex].name;
      final next = trip.nextStopIndex == null
          ? null
          : trip.stops[trip.nextStopIndex!].name;
      final whereNow = trip.isAtStop
          ? tr('Bus is at {0}', [current])
          : tr('Driving to {0}', [next]);

      // The bus is standing at the student's stop right now.
      if (hasMyStop && trip.isAtStop && myIndex == trip.lastReachedIndex) {
        return (
          title: tr('The bus is at your stop'),
          detail: toSchool
              ? tr('Please get on now{0}', [late])
              : tr('Time to get off{0}', [late]),
        );
      }

      // The student's stop is still ahead.
      if (hasMyStop && !trip.hasPassed(myIndex)) {
        final minutes = trip.minutesUntil(myIndex, now);
        final stopsAway = myIndex - trip.lastReachedIndex;
        return (
          title: minutes <= 1
              ? tr('Arriving at your stop now')
              : tr('{0} in {1} min', [
                  toSchool ? tr('At your stop') : tr('Home stop'),
                  minutes,
                ]),
          detail: stopsAway == 1
              ? tr('{0} · 1 stop away{1}', [whereNow, late])
              : tr('{0} · {1} stops away{2}', [whereNow, stopsAway, late]),
        );
      }

      return (
        title: toSchool ? tr('On the way to school') : tr('On the way home'),
        detail: '$whereNow$late',
      );

    case TripPhase.arrived:
      return toSchool
          ? (
              title: tr('Arrived at school'),
              detail: tr('at {0}', [at(trip.stops.length - 1)]),
            )
          : (
              title: tr('Trip finished'),
              detail: tr('Last stop at {0}', [at(trip.stops.length - 1)]),
            );

    case TripPhase.noTripToday:
      return (title: tr('No bus today'), detail: '');
  }
}

/// Worth showing on a home page? (During a trip, or shortly before.)
bool isTripRelevantNow(TripModel trip, DateTime now) {
  switch (trip.phase) {
    case TripPhase.onTheWay:
      return true;
    case TripPhase.notStarted:
      return trip.plannedTimes.first.difference(now).inMinutes <= 45;
    case TripPhase.arrived:
      // A live trip that just ended stays visible until the driver closes it.
      return trip.isLive;
    case TripPhase.noTripToday:
      return false;
  }
}

/// "2 h 10 min", "25 min", "1 min".
String durationText(Duration d) {
  final minutes = d.inMinutes < 1 ? 1 : d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return tr('{0} min', [m]);

  return m == 0 ? '$h h' : tr('{0} h {1} min', [h, m]);
}

/// One line about whether a trip can start, for the driver.
String tripAvailabilityText(TripAvailability trip, DateTime now) {
  String at(DateTime t) => DateFormatter.time(t);

  switch (trip.block) {
    case TripBlock.none:
      return tr('Open now · start by {0}', [at(trip.closesAt)]);
    case TripBlock.tooEarly:
      return tr('Opens at {0} · in {1}', [
        at(trip.opensAt),
        durationText(trip.opensAt.difference(now)),
      ]);
    case TripBlock.tooLate:
      return tr('Closed at {0}', [at(trip.closesAt)]);
    case TripBlock.alreadyDone:
      return tr('Done today at {0}', [at(trip.doneAt!)]);
    case TripBlock.noSchool:
      return tr('No trips today · {0}', [trip.dayOffReason]);
    case TripBlock.otherTripRunning:
      return tr('Finish the current trip first');
    case TripBlock.noStops:
      return tr('This line has no stops yet');
  }
}
