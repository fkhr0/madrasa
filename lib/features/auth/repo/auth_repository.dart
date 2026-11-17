import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> signIn({
    required String schoolId,
    required String password,
  });

  Future<void> signOut();

  Future<List<UserRole>> demoRoles();

  Future<UserModel> signInDemo(UserRole role);

  Future<UserModel?> restoreSession();

  Future<UserModel> reloadProfile();

  Future<void> sessionEnded();

  Future<void> requestPasswordReset(String emailOrPhone);

  Future<UserModel> updateContactInfo(
    UserModel user, {
    required String email,
    required String phone,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
