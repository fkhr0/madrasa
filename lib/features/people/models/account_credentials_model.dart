import '../../auth/models/user_model.dart';

/// Returned after creating an account or resetting a password.
/// The administrator hands these to the person (printed slip or message);
/// the person must change the password at first sign-in.
class AccountCredentialsModel {
  final UserModel user;
  final String temporaryPassword;

  const AccountCredentialsModel({
    required this.user,
    required this.temporaryPassword,
  });
}
