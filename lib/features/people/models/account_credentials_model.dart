import '../../auth/models/user_model.dart';

/// Returned after creating an account or resetting a password.
class AccountCredentialsModel {
  final UserModel user;
  final String temporaryPassword;

  const AccountCredentialsModel({
    required this.user,
    required this.temporaryPassword,
  });
}
