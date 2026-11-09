import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The push service worker (web/push/sw.js). Its own scope keeps it apart
/// from Flutter's.
const _worker = 'push/sw.js';
const _scope = 'push/';

bool get webPushSupported =>
    globalContext.has('PushManager') &&
    globalContext.has('Notification') &&
    web.window.navigator.has('serviceWorker');

String get webPushPermission =>
    webPushSupported ? web.Notification.permission : 'denied';

Future<Map<String, dynamic>?> subscribeToWebPush(String publicKey) async {
  if (!webPushSupported) return null;

  // Asking needs the tap that called this, so ask first.
  final answer = (await web.Notification.requestPermission().toDart).toDart;
  if (answer != 'granted') return null;

  final registration = await web.window.navigator.serviceWorker
      .register(_worker.toJS, web.RegistrationOptions(scope: _scope))
      .toDart;
  await _untilActive(registration);

  final manager = registration.pushManager;
  final subscription =
      await manager.getSubscription().toDart ??
      await manager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _bytes(publicKey).toJS,
            ),
          )
          .toDart;

  // {endpoint, expirationTime, keys: {p256dh, auth}}
  final json = globalContext
      .getProperty<JSObject>('JSON'.toJS)
      .callMethod<JSString>('stringify'.toJS, subscription)
      .toDart;
  return jsonDecode(json) as Map<String, dynamic>;
}

/// A new worker installs for a moment before it can receive pushes.
Future<void> _untilActive(web.ServiceWorkerRegistration registration) async {
  for (var i = 0; i < 50 && registration.active == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// The server's key ("BNc...", URL-safe base64) as bytes.
Uint8List _bytes(String key) =>
    base64Url.decode(key.padRight((key.length + 3) ~/ 4 * 4, '='));
