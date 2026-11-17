import '../../auth/models/user_model.dart';
import '../models/account_credentials_model.dart';
import '../models/new_account_model.dart';

abstract class PeopleRepository {
  Future<List<UserModel>> getByRole(UserRole role);

  Future<UserModel?> getById(String id);

  Future<AccountCredentialsModel> createAccount(NewAccountModel account);

  Future<UserModel> updateAccount(String id, NewAccountModel account);

  Future<void> setActive(String id, bool isActive);

  Future<AccountCredentialsModel> resetPassword(String id);

  Future<void> deleteAccount(String id);
}
