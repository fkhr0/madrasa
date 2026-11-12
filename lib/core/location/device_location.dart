import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/language.dart';

/// What the person can do about a location problem, from a button.
enum LocationFix {
  /// Location is off on the phone: open the phone's location settings.
  turnOn,

  /// The app may not use location: open this app's settings.
  allow,
  none,
}

/// Why the phone's location can't be read, ready to show to the user.
class LocationException implements Exception {
  final String message;
  final LocationFix fix;

  const LocationException(this.message, {this.fix = LocationFix.none});

  @override
  String toString() => message;
}

/// One GPS reading: where, and how sure the phone is (in metres).
class GpsFix {
  final LatLng point;

  /// The real place is within this many metres of [point].
  final double accuracy;

  const GpsFix(this.point, this.accuracy);
}

/// The phone's GPS. In a browser this only works on a secure address
/// (https or localhost); the installed app always can.
class DeviceLocation {
  DeviceLocation._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The installed app asks for permission first. A browser asks by itself
  /// on the first read (and some, like Safari, can't be asked beforehand).
  static Future<void> _ensureAllowed() async {
    if (kIsWeb) {
      // Browsers refuse location on plain http (except on this computer).
      final insecure =
          Uri.base.scheme == 'http' &&
          Uri.base.host != 'localhost' &&
          Uri.base.host != '127.0.0.1';
      if (insecure) {
        throw LocationException(
          tr(
            'This address cannot use GPS. Open the https '
            '(trycloudflare.com) link on this phone instead.',
          ),
        );
      }
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationException(
          tr('Turn on location on this phone.'),
          fix: LocationFix.turnOn,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw LocationException(_blockedMessage, fix: _allowFix);
      }
      // Android 12+ lets people share only a rough area (up to ~2 km off):
      // a bus or a home pin would be in the wrong street.
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        throw LocationException(
          tr(
            'Precise location is off. In the phone settings, open Apps, '
            'Madrasa, Location, and turn on "Use precise location".',
          ),
          fix: LocationFix.allow,
        );
      }
    } on LocationException {
      rethrow;
    } catch (e) {
      throw explain(e);
    }
  }

  static LocationFix get _allowFix =>
      kIsWeb ? LocationFix.none : LocationFix.allow;

  static String get _blockedMessage => kIsWeb
      ? tr(
          'Location is blocked for this site. Tap the lock or "aA" next to '
          'the address, allow Location, then tap Try again.',
        )
      : tr('Location is blocked. Allow it for this app in the phone settings.');

  /// A clear message for whatever went wrong.
  static LocationException explain(Object error) {
    if (error is LocationException) return error;
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('secure')) {
      return LocationException(
        tr('This address cannot use GPS. Open the https link instead.'),
      );
    }
    if (lower.contains('denied') || lower.contains('permission')) {
      return LocationException(_blockedMessage, fix: _allowFix);
    }
    if (lower.contains('timeout') || lower.contains('unavailable')) {
      return LocationException(
        tr(
          'No GPS signal yet. Go near a window or outside, then tap Try again.',
        ),
      );
    }
    if (lower.contains('disabled') || lower.contains('service')) {
      return LocationException(
        tr('Turn on location on this phone.'),
        fix: kIsWeb ? LocationFix.none : LocationFix.turnOn,
      );
    }
    return LocationException(
      tr('The location could not be read ({0}).', [text]),
    );
  }

  /// Asks for permission as soon as a map opens, so "I'm here" works on the
  /// first tap. Says nothing if refused: the tap explains then.
  static Future<void> askEarly() async {
    if (kIsWeb) return;
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  /// Opens the phone setting that fixes [fix].
  static Future<void> openSettingsFor(LocationFix fix) async {
    switch (fix) {
      case LocationFix.turnOn:
        await Geolocator.openLocationSettings();
      case LocationFix.allow:
        await Geolocator.openAppSettings();
      case LocationFix.none:
        break;
    }
  }

  /// The phone's position now. Tries precise GPS first; indoors, where
  /// GPS may never answer, falls back to the rough network position.
  static Future<LatLng> current() async => (await currentFix()).point;

  /// [current] with how accurate it is.
  static Future<GpsFix> currentFix() async {
    await _ensureAllowed();
    for (final accuracy in [LocationAccuracy.high, LocationAccuracy.low]) {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: const Duration(seconds: 15),
          ),
        );
        return GpsFix(LatLng(p.latitude, p.longitude), p.accuracy);
      } on TimeoutException {
        continue;
      } catch (e) {
        throw explain(e);
      }
    }
    throw explain(TimeoutException('timeout'));
  }

  /// A new reading whenever the phone moves [distanceFilter] metres.
  static Stream<GpsFix> watch({
    int distanceFilter = 10,
    bool keepRunning = false,
  }) async* {
    await _ensureAllowed();
    final settings = _isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: distanceFilter,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: keepRunning
                ? ForegroundNotificationConfig(
                    notificationTitle: tr('Sharing the bus location'),
                    notificationText: tr(
                      'Families see the bus until the trip ends.',
                    ),
                    notificationChannelName: tr('Bus location'),
                    notificationIcon: const AndroidResource(
                      name: 'ic_notification',
                    ),
                    color: const Color(0xFF4C5FD5),
                    // GPS keeps going while the phone sleeps in a pocket.
                    enableWakeLock: true,
                    setOngoing: true,
                  )
                : null,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: distanceFilter,
          );
    yield* Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => GpsFix(LatLng(p.latitude, p.longitude), p.accuracy))
        .handleError((Object e) => throw explain(e));
  }
}
