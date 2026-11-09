import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session_store.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Sign-in and the user's own account, on the school API.
/// Turns [ApiException] into [AuthException], so the pages stay the same.
class ApiAuthRepository implements AuthRepository {
  final ApiClient _api;
  final SessionStore _session;

  ApiAuthRepository(this._api, [this._session = const NoSessionStore()]) {
    _api.onTokensChanged = _session.saveToken;
  }

  @override
  Future<UserModel> signIn({
    required String schoolId,
    required String password,
  }) async {
    final data = await _guard(
      () => _api.post('/auth/login', {
        'schoolId': schoolId.trim(),
        'password': password,
      }),
    );

    return _signedIn(data as Map<String, dynamic>);
  }

  /// Keeps the tokens and the session (password or demo sign-in alike).
  Future<UserModel> _signedIn(Map<String, dynamic> data) async {
    _api.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final json = data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(json);
    // Saved answers are this person's own.
    _api.cacheOwner = user.id;
    // Stay signed in when the app is closed.
    await _session.save(data['refreshToken'] as String, json);
    return user;
  }

  @override
  Future<List<UserRole>> demoRoles() async {
    try {
      final data = await _api.get('/auth/demo') as Map<String, dynamic>;
      return [
        for (final name in data['roles'] as List)
          UserRole.fromName(name as String),
      ];
    } on ApiException {
      return const []; // no demo on this server
    }
  }

  @override
  Future<UserModel> signInDemo(UserRole role) async {
    final data = await _guard(
      () => _api.post('/auth/demo', {'role': role.name}),
    );
    return _signedIn(data as Map<String, dynamic>);
  }

  @override
  Future<UserModel?> restoreSession() async {
    final saved = await _session.read();
    if (saved == null) return null;
    _api.restoreSession(saved.refreshToken);
    final user = UserModel.fromJson(saved.user);
    _api.cacheOwner = user.id;
    return user;
  }

  @override
  Future<UserModel> reloadProfile() async {
    final json = await _guard(() => _api.get('/me')) as Map<String, dynamic>;
    final token = _api.refreshToken;
    if (token != null) await _session.save(token, json);
    return UserModel.fromJson(json);
  }

  @override
  Future<void> sessionEnded() async {
    await _session.clear();
    await _api.forgetSavedAnswers();
  }

  @override
  Future<void> signOut() async {
    final token = _api.refreshToken;
    _api.clearTokens();
    await _api.forgetSavedAnswers();
    await _session.clear();
    if (token == null) return;

    // Tell the server to end this device's session. If we are offline the
    // token simply expires later.
    try {
      await _api.post('/auth/logout', {'refreshToken': token});
    } on ApiException {
      // Already signed out on this device; nothing else to do.
    }
  }

  @override
  Future<void> requestPasswordReset(String emailOrPhone) => _guard(
    () => _api.post('/auth/password-reset', {'emailOrPhone': emailOrPhone}),
  );

  @override
  Future<UserModel> updateContactInfo(
    UserModel user, {
    required String email,
    required String phone,
  }) async {
    final data = await _guard(
      () => _api.patch('/me', {'email': email, 'phone': phone}),
    );
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(
    () => _api.post('/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      // Keeps this device signed in; others are signed out.
      'refreshToken': _api.refreshToken,
    }),
  );

  Future<dynamic> _guard(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }
}
