import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_model.dart';
import '../models/account_credentials_model.dart';
import '../models/new_account_model.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../repo/api_people_repository.dart';
import '../repo/mock_people_repository.dart';
import '../repo/people_repository.dart';

/// The server when API_URL is set, otherwise the mock directory.
final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => AppConfig.useApi
      ? ApiPeopleRepository(watchApi(ref))
      : MockPeopleRepository(),
);

/// The role chosen at the top of the People tab.
final peopleRoleProvider = StateProvider<UserRole>((ref) => UserRole.student);

final peopleSearchProvider = StateProvider<String>((ref) => '');

/// Reloads when another user signs in (another school's directory).
final peopleByRoleProvider = FutureProvider.family<List<UserModel>, UserRole>((
  ref,
  role,
) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(peopleRepositoryProvider).getByRole(role);
});

/// People of the selected role matching the search (name, ID or class).
final filteredPeopleProvider = FutureProvider<List<UserModel>>((ref) async {
  final role = ref.watch(peopleRoleProvider);
  final query = ref.watch(peopleSearchProvider).trim().toLowerCase();
  final people = await ref.watch(peopleByRoleProvider(role).future);

  if (query.isEmpty) return people;

  return people
      .where(
        (u) =>
            u.name.toLowerCase().contains(query) ||
            u.id.toLowerCase().contains(query) ||
            (u.className?.toLowerCase().contains(query) ?? false),
      )
      .toList();
});

final personByIdProvider = FutureProvider.family<UserModel?, String>((ref, id) {
  // Reload when any list changes (e.g. after deactivating).
  for (final role in UserRole.values) {
    ref.watch(peopleByRoleProvider(role));
  }
  return ref.watch(peopleRepositoryProvider).getById(id);
});

final peopleActionsProvider = Provider<PeopleActions>(PeopleActions.new);

/// Administrator actions on accounts. Each one reloads the lists.
class PeopleActions {
  final Ref _ref;

  PeopleActions(this._ref);

  PeopleRepository get _repository => _ref.read(peopleRepositoryProvider);

  Future<AccountCredentialsModel> create(NewAccountModel account) async {
    final credentials = await _repository.createAccount(account);
    _ref.invalidate(peopleByRoleProvider(account.role));
    return credentials;
  }

  Future<void> setActive(UserModel user, bool isActive) async {
    await _repository.setActive(user.id, isActive);
    _ref.invalidate(peopleByRoleProvider(user.role));
  }

  Future<UserModel> update(UserModel user, NewAccountModel account) async {
    final updated = await _repository.updateAccount(user.id, account);
    _ref.invalidate(peopleByRoleProvider(user.role));
    return updated;
  }

  Future<void> delete(UserModel user) async {
    await _repository.deleteAccount(user.id);
    _ref.invalidate(peopleByRoleProvider(user.role));
  }

  Future<AccountCredentialsModel> resetPassword(UserModel user) =>
      _repository.resetPassword(user.id);
}
