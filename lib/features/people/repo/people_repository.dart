import '../../auth/models/user_model.dart';
import '../models/account_credentials_model.dart';
import '../models/new_account_model.dart';

/// The school's accounts, managed by the administrator.
/// MockPeopleRepository (mock data) or ApiPeopleRepository (the server, which
/// generates IDs and passwords; the app never makes them up).
abstract class PeopleRepository {
  /// Everyone with [role], sorted by name.
  Future<List<UserModel>> getByRole(UserRole role);

  Future<UserModel?> getById(String id);

  /// Creates the account with a generated ID and temporary password.
  Future<AccountCredentialsModel> createAccount(NewAccountModel account);

  /// Changes name, contact, class/subject or children. The role and ID
  /// never change.
  Future<UserModel> updateAccount(String id, NewAccountModel account);

  /// Deactivated users cannot sign in; their history is kept.
  Future<void> setActive(String id, bool isActive);

  /// Returns a new temporary password.
  Future<AccountCredentialsModel> resetPassword(String id);

  /// For mistakes (wrong or duplicate accounts). People who leave should be
  /// deactivated instead.
  Future<void> deleteAccount(String id);
}
