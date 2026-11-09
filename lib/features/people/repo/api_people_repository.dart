import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';
import '../models/account_credentials_model.dart';
import '../models/new_account_model.dart';
import 'people_repository.dart';

/// The People directory on the school API (server/src/features/people).
class ApiPeopleRepository implements PeopleRepository {
  final ApiClient _api;

  const ApiPeopleRepository(this._api);

  @override
  Future<List<UserModel>> getByRole(UserRole role) async {
    final list = await _api.get('/people?role=${role.name}') as List;
    return [
      for (final json in list) UserModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<UserModel?> getById(String id) async =>
      UserModel.fromJson(await _api.get('/people/$id') as Map<String, dynamic>);

  @override
  Future<AccountCredentialsModel> createAccount(
    NewAccountModel account,
  ) async => _credentials(
    await _api.post('/people', {
      'role': account.role.name,
      ..._fields(account),
    }),
  );

  @override
  Future<UserModel> updateAccount(String id, NewAccountModel account) async =>
      UserModel.fromJson(
        await _api.patch('/people/$id', _fields(account))
            as Map<String, dynamic>,
      );

  @override
  Future<void> setActive(String id, bool isActive) =>
      _api.post('/people/$id/active', {'isActive': isActive});

  @override
  Future<AccountCredentialsModel> resetPassword(String id) async =>
      _credentials(await _api.post('/people/$id/reset-password'));

  @override
  Future<void> deleteAccount(String id) => _api.delete('/people/$id');

  static Map<String, dynamic> _fields(NewAccountModel a) => {
    'name': a.name,
    'email': a.email,
    'phone': a.phone,
    'className': a.className,
    'subjectName': a.subjectName,
    'childIds': a.childIds,
  };

  static AccountCredentialsModel _credentials(dynamic json) =>
      AccountCredentialsModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        temporaryPassword: json['temporaryPassword'] as String,
      );
}
