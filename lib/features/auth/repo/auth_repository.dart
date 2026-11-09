import '../models/user_model.dart';

/// What the app needs from the authentication backend.
/// Pages never talk to the server directly, only through this contract.
/// Today: MockAuthRepository. Backend stage: ApiAuthRepository.
abstract class AuthRepository {
  /// [schoolId] is the ID the school generated for the student,
  /// teacher or parent. Throws [AuthException] on wrong credentials.
  Future<UserModel> signIn({
    required String schoolId,
    required String password,
  });

  Future<void> signOut();

  /// The roles "Try the demo" offers, or empty when the server has no demo.
  Future<List<UserRole>> demoRoles();

  /// "Try the demo": the demo school as [role], without a password.
  Future<UserModel> signInDemo(UserRole role);

  /// The person signed in last time, when the session was saved on this
  /// device (no network needed). Null: show the sign-in page.
  Future<UserModel?> restoreSession();

  /// The profile as the server has it now (it may have changed since).
  Future<UserModel> reloadProfile();

  /// The server ended the session: forget everything saved for it.
  Future<void> sessionEnded();

  /// Sends a reset code to the email or phone linked to the account.
  Future<void> requestPasswordReset(String emailOrPhone);

  /// Name, class and ID are managed by the school; users edit contact info only.
  Future<UserModel> updateContactInfo(
    UserModel user, {
    required String email,
    required String phone,
  });

  /// Throws [AuthException] when [currentPassword] is wrong.
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
