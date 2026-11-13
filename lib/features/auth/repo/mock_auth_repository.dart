import '../data/mock_users.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Accepts any password of 4+ characters.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<UserModel> signIn({
    required String schoolId,
    required String password,
  }) async {
    // Pretend we are talking to a server.
    await Future.delayed(const Duration(milliseconds: 700));

    if (password.length < 4) {
      throw const AuthException('The ID or password is not correct.');
    }

    final id = schoolId.trim().toUpperCase();
    if (id.startsWith('TCH')) return MockUsers.teacher;
    if (id.startsWith('PAR')) return MockUsers.parent;
    if (id.startsWith('ADM')) return MockUsers.admin;
    if (id.startsWith('DRV')) return MockUsers.driver;

    return MockUsers.student;
  }

  @override
  Future<void> signOut() async {}

  /// Mock mode lists the demo accounts on the sign-in page instead.
  @override
  Future<List<UserRole>> demoRoles() async => const [];

  @override
  Future<UserModel> signInDemo(UserRole role) =>
      signIn(schoolId: '${role.idPrefix}-demo', password: 'demo');

  @override
  Future<UserModel?> restoreSession() async => null;

  @override
  Future<UserModel> reloadProfile() =>
      throw UnsupportedError('Mock accounts are never restored');

  @override
  Future<void> sessionEnded() async {}

  @override
  Future<void> requestPasswordReset(String emailOrPhone) async {
    await Future.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<UserModel> updateContactInfo(
    UserModel user, {
    required String email,
    required String phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return user.copyWith(email: email, phone: phone);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (currentPassword.length < 4) {
      throw const AuthException('Your current password is not correct.');
    }
  }
}
