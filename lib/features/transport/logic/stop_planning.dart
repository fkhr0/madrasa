import 'dart:math';

import '../models/bus_stop_model.dart';
import '../models/road_path_model.dart';
import '../../../core/l10n/language.dart';

/// Helpers for the administrator's stop editor.
/// Stops are in morning order and the school is always last.

/// Where a new stop at ([lat], [lng]) adds the least driving: the index to
/// insert it at (never after the school).
int bestInsertIndex(List<BusStopModel> stops, double lat, double lng) {
  if (stops.length <= 1) return 0;

  double d(double aLat, double aLng, double bLat, double bLng) =>
      sqrt(pow(aLat - bLat, 2) + pow(aLng - bLng, 2));

  var best = 0;
  var bestExtra = double.infinity;

  for (var i = 0; i < stops.length; i++) {
    final next = stops[i];
    final double extra;

    if (i == 0) {
      // A new first stop: the bus drives from it to the old first stop.
      extra = d(lat, lng, next.latitude, next.longitude);
    } else {
      final prev = stops[i - 1];
      extra =
          d(prev.latitude, prev.longitude, lat, lng) +
          d(lat, lng, next.latitude, next.longitude) -
          d(prev.latitude, prev.longitude, next.latitude, next.longitude);
    }

    if (extra < bestExtra) {
      bestExtra = extra;
      best = i;
    }
  }

  return best;
}

/// Planned times for a stop inserted at [index] of [stops]: halfway
/// between its neighbours in the morning, mirrored in the afternoon.
(int morning, int afternoon) suggestedTimes(
  List<BusStopModel> stops,
  int index,
) {
  final school = stops.last;
  final next = stops[index];
  final morning = index == 0
      ? next.morningMinute - 10
      : (stops[index - 1].morningMinute + next.morningMinute) ~/ 2;

  return (morning, afternoonFor(school, morning));
}

/// The afternoon trip drives the same road backwards: a stop reached
/// N minutes before school in the morning is reached N minutes after the
/// bus leaves school in the afternoon.
int afternoonFor(BusStopModel school, int morningMinute) =>
    school.afternoonMinute + (school.morningMinute - morningMinute);

/// A problem with the planned times, or null when they are in order.
String? timetableProblem(List<BusStopModel> stops) {
  for (var i = 1; i < stops.length; i++) {
    if (stops[i].morningMinute <= stops[i - 1].morningMinute) {
      return tr(
        'Morning times must get later towards the school ({0} → {1}).',
        [stops[i - 1].name, stops[i].name],
      );
    }
    if (stops[i].afternoonMinute >= stops[i - 1].afternoonMinute) {
      return tr(
        'Afternoon times must get later away from the school ({0} → {1}).',
        [stops[i].name, stops[i - 1].name],
      );
    }
  }

  return null;
}

/// Spreads the morning times evenly from the first stop to the school,
/// keeping both ends, and mirrors them for the afternoon.
List<BusStopModel> evenTimes(List<BusStopModel> stops) {
  if (stops.length < 2) return stops;

  final school = stops.last;
  final end = school.morningMinute;
  var start = stops.first.morningMinute;
  final gaps = stops.length - 1;
  if (start >= end - gaps) start = end - gaps * 10;

  return [
    for (var i = 0; i < stops.length; i++)
      if (i == stops.length - 1)
        school
      else
        stops[i].copyWith(
          morningMinute: start + ((end - start) * i / gaps).round(),
          afternoonMinute: afternoonFor(
            school,
            start + ((end - start) * i / gaps).round(),
          ),
        ),
  ];
}

/// How long the bus waits at each stop for students to get on or off.
const stopWaitMinutes = 1;

/// Times from the real driving times on the roads: the school times stay,
/// each earlier stop is one drive (plus a short wait) before the next.
/// [toSchool] and [toHome] are the line's roads (afternoon may be missing).
List<BusStopModel> timesFromRoads(
  List<BusStopModel> stops,
  RoadPathModel toSchool,
  RoadPathModel? toHome,
) {
  int minutesOf(int seconds) => (seconds / 60).ceil() + stopWaitMinutes;

  // Morning: backwards from the school's arrival time.
  final morning = List<int>.filled(stops.length, stops.last.morningMinute);
  for (var i = stops.length - 2; i >= 0; i--) {
    morning[i] = morning[i + 1] - minutesOf(toSchool.legSeconds[i]);
  }

  // Afternoon: forwards from the school's leaving time, stops in reverse.
  final afternoon = List<int>.filled(stops.length, stops.last.afternoonMinute);
  final back = toHome ?? toSchool;
  for (var k = 1; k < stops.length; k++) {
    final i = stops.length - 1 - k;
    final leg = back.legSeconds[k - 1];
    afternoon[i] = afternoon[i + 1] + minutesOf(leg);
  }

  return [
    for (var i = 0; i < stops.length; i++)
      stops[i].copyWith(
        morningMinute: morning[i],
        afternoonMinute: afternoon[i],
      ),
  ];
}
