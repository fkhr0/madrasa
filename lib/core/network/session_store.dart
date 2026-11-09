import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What keeps someone signed in after the app is closed: the refresh token and
/// the last copy of their profile.
abstract class SessionStore {
  Future<SavedSession?> read();
  Future<void> save(String refreshToken, Map<String, dynamic> user);

  /// The server gives a new refresh token each time it is used.
  Future<void> saveToken(String refreshToken);
  Future<void> clear();
}

class SavedSession {
  final String refreshToken;
  final Map<String, dynamic> user;

  const SavedSession(this.refreshToken, this.user);
}

class SecureSessionStore implements SessionStore {
  static const _token = 'session.refreshToken';
  static const _user = 'session.user';
  final _storage = const FlutterSecureStorage();

  @override
  Future<SavedSession?> read() async {
    try {
      final token = await _storage.read(key: _token);
      final user = await _storage.read(key: _user);
      if (token == null || user == null) return null;
      return SavedSession(token, jsonDecode(user) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable (e.g. the phone's keys were reset): sign in again.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(String refreshToken, Map<String, dynamic> user) async {
    await _storage.write(key: _token, value: refreshToken);
    await _storage.write(key: _user, value: jsonEncode(user));
  }

  @override
  Future<void> saveToken(String refreshToken) =>
      _storage.write(key: _token, value: refreshToken);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _token);
    await _storage.delete(key: _user);
  }
}

/// Remembers nothing (tests).
class NoSessionStore implements SessionStore {
  const NoSessionStore();

  @override
  Future<SavedSession?> read() async => null;

  @override
  Future<void> save(String refreshToken, Map<String, dynamic> user) async {}

  @override
  Future<void> saveToken(String refreshToken) async {}

  @override
  Future<void> clear() async {}
}
