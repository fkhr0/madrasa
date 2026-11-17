import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PhonePush {
  PhonePush._();

  static bool _ready = false;

  static String? _id;

  static var _idReady = Completer<String>();

  static bool get supported => _ready;

  static Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      return;
    }
    _messaging.onRegistered.listen((id) {
      _id = id;
      if (!_idReady.isCompleted) _idReady.complete(id);
    });
  }

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

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

  static Future<String?> askAndGetId() async {
    if (!_ready) return null;
    await _messaging.requestPermission();
    return idIfAllowed();
  }

  static Future<String?> idIfAllowed() async {
    if (await permission() != 'granted') return null;
    if (_id case final id?) return id;
    await _messaging.register();
    return _idReady.future.timeout(const Duration(seconds: 30));
  }

  static String? get lastId => _id;

  static Stream<String> get idChanges => _ready
      ? _messaging.onRegistered.map((id) => _id = id)
      : const Stream.empty();

  static Future<void> forget() async {
    if (!_ready) return;
    await _messaging.unregister();
    _id = null;
    _idReady = Completer<String>();
  }

  static Future<String?> openedFrom() async {
    if (!_ready) return null;
    return (await _messaging.getInitialMessage())?.data['route'] as String?;
  }

  static Stream<String> get taps => _ready
      ? FirebaseMessaging.onMessageOpenedApp
            .map((m) => m.data['route'] as String?)
            .where((r) => r != null)
            .cast<String>()
      : const Stream.empty();

  static Stream<RemoteMessage> get whileOpen =>
      _ready ? FirebaseMessaging.onMessage : const Stream.empty();
}
