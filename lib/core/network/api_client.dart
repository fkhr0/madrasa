import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/language.dart';
import 'api_exception.dart';
import 'response_cache.dart';

/// Talks to the school API (server/ folder).
class ApiClient {
  /// Changes only in test builds, when the sign-in page sets the address.
  String baseUrl;
  final http.Client _http;

  /// The answers saved on this device.
  final ResponseCache cache;

  /// Whose saved answers to use (the signed-in person's ID).
  String? cacheOwner;

  /// True while the screens show saved answers because the server can't be
  /// reached.
  final offline = ValueNotifier<bool>(false);

  /// Saved answers shown at once this session (each is checked once).
  final _shownSaved = <String>{};

  /// The background checks found newer data than the saved answers shown.
  void Function()? onSavedAnswersOutdated;
  Timer? _outdatedSoon;

  /// Called when the user must sign in again.
  void Function()? onSessionExpired;

  /// Called with the new refresh token after each refresh (it works only
  /// once, so the saved one must be replaced).
  void Function(String refreshToken)? onTokensChanged;

  static const _timeout = Duration(seconds: 20);

  /// A video on mobile data takes a while.
  static const _uploadTimeout = Duration(minutes: 3);

  String? _accessToken;
  String? _refreshToken;

  /// The refresh in progress, shared by requests that fail at the same time
  /// (a refresh token works only once).
  Future<bool>? _refreshing;

  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.cache = const NoResponseCache(),
  }) : _http = client ?? http.Client();

  String? get refreshToken => _refreshToken;

  /// For the live connection's sign-in (realtime_client.dart).
  String? get accessToken => _accessToken;

  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Opening the app with a saved session: the next request gets a fresh
  /// access token with [refreshToken] first.
  void restoreSession(String refreshToken) {
    _accessToken = null;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  /// Signing out: nobody else on this phone may see the saved answers.
  Future<void> forgetSavedAnswers() async {
    cacheOwner = null;
    _shownSaved.clear();
    await cache.clear();
  }

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, Object body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> put(String path, Object body) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body: body);

  /// Sends a file's bytes as the body (POST /files). Returns the server's JSON.
  Future<dynamic> upload(
    String path,
    List<int> bytes, {
    required String fileName,
    required String contentType,
  }) => _send(
    'POST',
    path,
    bytes: bytes,
    timeout: _uploadTimeout,
    headers: {
      'Content-Type': contentType,
      'X-File-Name': Uri.encodeComponent(fileName),
    },
  );

  /// [path] on the server as a full address, e.g. for a download link.
  Uri resolve(String path) => Uri.parse('$baseUrl$path');

  // ---------- plumbing ----------

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    List<int>? bytes,
    Map<String, String> headers = const {},
    bool canRefresh = true,
    Duration timeout = _timeout,
    bool fromServer = false,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json'
      // Answers, errors and this person's notifications in the app's
      // language (the server remembers it).
      ..headers['X-Language'] = AppLanguage.current.name;
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    if (bytes != null) request.bodyBytes = bytes;
    request.headers.addAll(headers);

    // A saved answer: ask "changed since this version?"
    final owner = cacheOwner;
    final cacheKey = '${AppLanguage.current.name} $path';
    final canCache =
        method == 'GET' && owner != null && !path.startsWith('/files/');
    final saved = canCache ? await cache.read(owner, cacheKey) : null;
    if (saved != null) request.headers['If-None-Match'] = saved.etag;

    // First time this session: the saved answer now, the check after.
    if (saved != null && !fromServer && _shownSaved.add(cacheKey)) {
      unawaited(_checkSaved(path, owner!, cacheKey, saved.etag));
      return jsonDecode(saved.body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      );
    } on TimeoutException {
      if (saved != null) return _offlineAnswer(saved);
      throw ApiException(tr('The server is taking too long. Try again.'));
    } on http.ClientException {
      if (saved != null) return _offlineAnswer(saved);
      throw ApiException(
        tr('Can\'t reach the server. Check your internet connection.'),
      );
    }
    offline.value = false;

    // Not changed: the saved answer is still right.
    if (response.statusCode == 304 && saved != null) {
      return jsonDecode(saved.body);
    }

    // Expired access token: refresh once, then repeat the request.
    final isAuthCall = path.startsWith('/auth/');
    if (response.statusCode == 401 && canRefresh && !isAuthCall) {
      if (await _refresh()) {
        return _send(
          method,
          path,
          body: body,
          bytes: bytes,
          headers: headers,
          canRefresh: false,
          timeout: timeout,
          fromServer: fromServer,
        );
      }
      clearTokens();
      onSessionExpired?.call();
    }

    final data = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 400) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : tr('Something went wrong ({0}).', [response.statusCode]);
      throw ApiException(message, status: response.statusCode);
    }

    final etag = response.headers['etag'];
    if (canCache && etag != null) {
      await cache.write(
        owner,
        cacheKey,
        CachedResponse(etag: etag, body: utf8.decode(response.bodyBytes)),
      );
    }
    return data;
  }

  /// Asks the server for what was shown from the phone; newer data makes
  /// the screens load again (once for a burst of checks).
  Future<void> _checkSaved(
    String path,
    String owner,
    String cacheKey,
    String shownEtag,
  ) async {
    try {
      await _send('GET', path, fromServer: true);
    } catch (_) {
      return; // offline or refused: what is shown stays
    }
    final now = await cache.read(owner, cacheKey);
    if (now == null || now.etag == shownEtag) return;
    _outdatedSoon?.cancel();
    _outdatedSoon = Timer(
      const Duration(milliseconds: 300),
      () => onSavedAnswersOutdated?.call(),
    );
  }

  dynamic _offlineAnswer(CachedResponse saved) {
    offline.value = true;
    return jsonDecode(saved.body);
  }

  Future<bool> _refresh() {
    final token = _refreshToken;
    if (token == null) return Future.value(false);

    return _refreshing ??= () async {
      try {
        final data = await _send(
          'POST',
          '/auth/refresh',
          body: {'refreshToken': token},
          canRefresh: false,
        );
        setTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        onTokensChanged?.call(_refreshToken!);
        return true;
      } on ApiException {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }
}
