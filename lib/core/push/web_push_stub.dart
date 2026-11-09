// Not in a browser (tests, the Android app): no Web Push.

bool get webPushSupported => false;

String get webPushPermission => 'denied';

Future<Map<String, dynamic>?> subscribeToWebPush(String publicKey) async =>
    null;
