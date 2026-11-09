import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Notifications on the installed Android app while it is closed, through
/// Firebase Cloud Messaging (FCM).
class PhonePush {
  PhonePush._();

  static bool _ready = false;

  /// This phone's ID with Firebase, once registered.
  static String? _id;

  /// Completes when Firebase gives this phone its ID (any time after start).
  static var _idReady = Completer<String>();

  /// This is the Android app and Firebase started.
  static bool get supported => _ready;

  /// Called once in main().
  static Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      // No google-services.json in this build.
      return;
    }
    // Listen from the start: Firebase may give the ID before anyone asks
    // (and only once), so waiting for it later could wait forever.
    _messaging.onRegistered.listen((id) {
      _id = id;
      if (!_idReady.isCompleted) _idReady.complete(id);
    });
  }

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// "granted", "denied" or "default" (not asked yet), like Web Push.
  static Future<String> permission() async {
    if (!_ready) return 'denied';
    final settings = await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => 'granted',
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => 'denied',
      AuthorizationStatus.notDetermined => 'default',
    };
  }

  /// Asks the person (Android 13+), then returns this phone's ID for the
  /// server, or null if they said no.
  static Future<String?> askAndGetId() async {
    if (!_ready) return null;
    await _messaging.requestPermission();
    return idIfAllowed();
  }

  /// This phone's ID when notifications are allowed (no question asked).
  static Future<String?> idIfAllowed() async {
    if (await permission() != 'granted') return null;
    if (_id case final id?) return id;
    await _messaging.register();
    return _idReady.future.timeout(const Duration(seconds: 30));
  }

  /// The last ID this phone got (to tell the server on sign-out).
  static String? get lastId => _id;

  /// Firebase gives a new ID now and then; the server needs it.
  static Stream<String> get idChanges => _ready
      ? _messaging.onRegistered.map((id) => _id = id)
      : const Stream.empty();

  /// Signed out: this ID stops working, so nothing more reaches the phone
  /// for that person (even if telling the server failed).
  static Future<void> forget() async {
    if (!_ready) return;
    await _messaging.unregister();
    _id = null;
    _idReady = Completer<String>();
  }

  /// The page to open: the notification tapped to open the app, if any.
  static Future<String?> openedFrom() async {
    if (!_ready) return null;
    return (await _messaging.getInitialMessage())?.data['route'] as String?;
  }

  /// Notifications tapped while the app was in the background.
  static Stream<String> get taps => _ready
      ? FirebaseMessaging.onMessageOpenedApp
            .map((m) => m.data['route'] as String?)
            .where((r) => r != null)
            .cast<String>()
      : const Stream.empty();

  /// Arrived while the app is open (it shows its own banner).
  static Stream<RemoteMessage> get whileOpen =>
      _ready ? FirebaseMessaging.onMessage : const Stream.empty();
}
