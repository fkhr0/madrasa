import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'auth_provider.dart';

final selectedChildIndexProvider = StateProvider<int>((ref) {
  ref.watch(authProvider);
  return 0;
});

final activeStudentProvider = Provider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);

  switch (user.role) {
    case UserRole.student:
      return user;
    case UserRole.parent:
      if (user.children.isEmpty) return null;
      final index = ref.watch(selectedChildIndexProvider);
      return user.children[index.clamp(0, user.children.length - 1)];
    case UserRole.teacher:
    case UserRole.admin:
    case UserRole.driver:
      return null;
  }
});

final activeStudentIdProvider = Provider<String>(
  (ref) => ref.watch(activeStudentProvider)?.id ?? '',
);
