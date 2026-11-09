import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/network/session_store.dart';
import '../models/user_model.dart';
import '../repo/api_auth_repository.dart';
import '../repo/auth_repository.dart';
import '../repo/mock_auth_repository.dart';

/// The server when API_URL is set, otherwise the mock accounts.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppConfig.useApi) return const MockAuthRepository();

  final api = ref.watch(apiClientProvider);
  // The server refused to refresh the session: back to the login page.
  api.onSessionExpired = () => ref.read(authProvider.notifier).sessionExpired();
  return ApiAuthRepository(api, ref.watch(sessionStoreProvider));
});

/// Where the session is kept between app launches (replaced in tests).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

/// The signed-in user, or null when signed out.
/// The router listens to this to show the login page or the app.
final authProvider = NotifierProvider<AuthController, UserModel?>(
  AuthController.new,
);

class AuthController extends Notifier<UserModel?> {
  UserModel? _lastUser;

  @override
  UserModel? build() => null;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// The most recent signed-in user. Kept after sign-out so the screens
  /// that are still animating away can finish building.
  UserModel? get lastUser => _lastUser;

  /// Opening the app: the person from last time, at once (even offline),
  /// then their profile as the server has it now.
  Future<void> restore() async {
    final user = await _repository.restoreSession();
    if (user == null) return;
    _lastUser = user;
    state = user;
    _reloadProfile();
  }

  Future<void> _reloadProfile() async {
    try {
      final user = await _repository.reloadProfile();
      if (state == null) return; // signed out meanwhile
      _lastUser = user;
      state = user;
    } catch (_) {
      // Offline: the saved profile stays. A refused session is handled by
      // sessionExpired().
    }
  }

  /// "Try the demo" as [role].
  Future<void> signInDemo(UserRole role) async {
    final user = await _repository.signInDemo(role);
    _lastUser = user;
    state = user;
  }

  /// Throws [AuthException] so the login page can show the message.
  Future<void> signIn({
    required String schoolId,
    required String password,
  }) async {
    final user = await _repository.signIn(
      schoolId: schoolId,
      password: password,
    );
    _lastUser = user;
    state = user;
  }

  Future<void> updateContactInfo({
    required String email,
    required String phone,
  }) async {
    final user = state;
    if (user == null) return;

    final updated = await _repository.updateContactInfo(
      user,
      email: email,
      phone: phone,
    );
    _lastUser = updated;
    state = updated;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = null;
  }

  /// After the user chose their own password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    final user = state;
    if (user != null && user.mustChangePassword) {
      state = _lastUser = user.copyWith(mustChangePassword: false);
    }
  }

  /// The server ended the session (password changed elsewhere, account
  /// deactivated, 30 days without use). The router shows the login page.
  void sessionExpired() {
    state = null;
    _repository.sessionEnded();
  }
}

/// Shortcut for screens that only exist while signed in.
final currentUserProvider = Provider<UserModel>((ref) {
  final user =
      ref.watch(authProvider) ?? ref.read(authProvider.notifier).lastUser;
  if (user == null) throw StateError('No signed-in user');

  return user;
});

/// The roles the server's demo offers (empty: no "Try the demo" button).
final demoRolesProvider = FutureProvider<List<UserRole>>(
  (ref) => ref.read(authRepositoryProvider).demoRoles(),
);
