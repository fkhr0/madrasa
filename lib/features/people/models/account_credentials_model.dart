import '../../auth/models/user_model.dart';

class AccountCredentialsModel {
  final UserModel user;
  final String temporaryPassword;

  const AccountCredentialsModel({
    required this.user,
    required this.temporaryPassword,
  });
}
