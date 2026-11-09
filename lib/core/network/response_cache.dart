import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A server answer saved on the device.
class CachedResponse {
  /// The server's version tag for it ("has it changed since?").
  final String etag;
  final String body;

  const CachedResponse({required this.etag, required this.body});
}

/// The answers to GET requests, saved on the device (used by ApiClient).
abstract class ResponseCache {
  Future<CachedResponse?> read(String owner, String key);
  Future<void> write(String owner, String key, CachedResponse response);
  Future<void> clear();
}

/// Saved with shared_preferences (the browser's storage on the web, the
/// app's settings file on Android).
class DeviceResponseCache implements ResponseCache {
  static const _prefix = 'api-cache:';

  /// Bigger answers aren't kept: the browser's storage holds about 5 MB.
  static const maxBodyLength = 200 * 1024;

  String _keyOf(String owner, String key) => '$_prefix$owner $key';

  @override
  Future<CachedResponse?> read(String owner, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyOf(owner, key));
    if (saved == null) return null;
    final json = jsonDecode(saved) as Map<String, dynamic>;
    return CachedResponse(
      etag: json['etag'] as String,
      body: json['body'] as String,
    );
  }

  @override
  Future<void> write(String owner, String key, CachedResponse response) async {
    if (response.body.length > maxBodyLength) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(
        _keyOf(owner, key),
        jsonEncode({'etag': response.etag, 'body': response.body}),
      );
    } catch (_) {
      // The storage is full: start again empty rather than fail the screen.
      await clear();
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

/// Keeps nothing (tests, mock mode).
class NoResponseCache implements ResponseCache {
  const NoResponseCache();

  @override
  Future<CachedResponse?> read(String owner, String key) async => null;

  @override
  Future<void> write(String owner, String key, CachedResponse r) async {}

  @override
  Future<void> clear() async {}
}
