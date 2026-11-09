import 'dart:math';

import '../../auth/models/user_model.dart';
import '../data/mock_people.dart';
import '../models/account_credentials_model.dart';
import '../models/new_account_model.dart';
import 'people_repository.dart';

/// Keeps accounts in memory and imitates the server's ID generator:
/// PREFIX-YEAR-NUMBER, e.g. STU-2026-0160.
class MockPeopleRepository implements PeopleRepository {
  final List<UserModel> _users = MockPeople.all;
  final _random = Random();

  @override
  Future<List<UserModel>> getByRole(UserRole role) async {
    return _users.where((u) => u.role == role).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<UserModel?> getById(String id) async {
    for (final user in _users) {
      if (user.id == id) return user;
    }

    return null;
  }

  @override
  Future<AccountCredentialsModel> createAccount(NewAccountModel account) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final user = UserModel(
      id: _nextId(account.role),
      name: account.name,
      role: account.role,
      email: account.email,
      phone: account.phone,
      schoolName: 'Al-Noor Preparatory School',
      className: account.className,
      subjectName: account.subjectName,
      children: _users.where((u) => account.childIds.contains(u.id)).toList(),
    );
    _users.add(user);

    return AccountCredentialsModel(user: user, temporaryPassword: _password());
  }

  @override
  Future<UserModel> updateAccount(String id, NewAccountModel account) async {
    final index = _users.indexWhere((u) => u.id == id);
    final old = _users[index];
    final updated = UserModel(
      id: old.id,
      name: account.name,
      role: old.role,
      email: account.email,
      phone: account.phone,
      schoolName: old.schoolName,
      className: account.className,
      subjectName: account.subjectName,
      children: old.role == UserRole.parent
          ? _users.where((u) => account.childIds.contains(u.id)).toList()
          : old.children,
      isActive: old.isActive,
    );
    _users[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteAccount(String id) async {
    _users.removeWhere((u) => u.id == id);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index] = _users[index].copyWith(isActive: isActive);
    }
  }

  @override
  Future<AccountCredentialsModel> resetPassword(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final user = (await getById(id))!;
    return AccountCredentialsModel(user: user, temporaryPassword: _password());
  }

  /// Next free number for this role in the current year.
  String _nextId(UserRole role) {
    final year = DateTime.now().year;
    final prefix = '${role.idPrefix}-$year-';

    final used = _users
        .where((u) => u.id.startsWith(prefix))
        .map((u) => int.parse(u.id.substring(prefix.length)));
    final next = used.isEmpty ? 1 : used.reduce(max) + 1;

    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  /// 8 characters, without letters that look alike (0/O, 1/l/I).
  String _password() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
