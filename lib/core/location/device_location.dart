import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/language.dart';

enum LocationFix { turnOn, allow, none }

class LocationException implements Exception {
  final String message;
  final LocationFix fix;

  const LocationException(this.message, {this.fix = LocationFix.none});

  @override
  String toString() => message;
}

class GpsFix {
  final LatLng point;

  final double accuracy;

  const GpsFix(this.point, this.accuracy);
}

class DeviceLocation {
  DeviceLocation._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _ensureAllowed() async {
    if (kIsWeb) {
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

  static Future<void> askEarly() async {
    if (kIsWeb) return;
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

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

  static Future<LatLng> current() async => (await currentFix()).point;

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
