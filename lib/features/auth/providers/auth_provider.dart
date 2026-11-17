import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/network/session_store.dart';
import '../models/user_model.dart';
import '../repo/api_auth_repository.dart';
import '../repo/auth_repository.dart';
import '../repo/mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppConfig.useApi) return const MockAuthRepository();

  final api = ref.watch(apiClientProvider);
  api.onSessionExpired = () => ref.read(authProvider.notifier).sessionExpired();
  return ApiAuthRepository(api, ref.watch(sessionStoreProvider));
});

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final authProvider = NotifierProvider<AuthController, UserModel?>(
  AuthController.new,
);

class AuthController extends Notifier<UserModel?> {
  UserModel? _lastUser;

  @override
  UserModel? build() => null;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  UserModel? get lastUser => _lastUser;

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
      if (state == null) return;
      _lastUser = user;
      state = user;
    } catch (_) {
      // offline: keep the saved profile
    }
  }

  Future<void> signInDemo(UserRole role) async {
    final user = await _repository.signInDemo(role);
    _lastUser = user;
    state = user;
  }

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

  void sessionExpired() {
    state = null;
    _repository.sessionEnded();
  }
}

final currentUserProvider = Provider<UserModel>((ref) {
  final user =
      ref.watch(authProvider) ?? ref.read(authProvider.notifier).lastUser;
  if (user == null) throw StateError('No signed-in user');

  return user;
});

final demoRolesProvider = FutureProvider<List<UserRole>>(
  (ref) => ref.read(authRepositoryProvider).demoRoles(),
);
