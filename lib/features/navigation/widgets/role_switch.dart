import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Shows a different page for each role at the same place in the app, e.g.
class RoleSwitch extends ConsumerWidget {
  final Widget student;
  final Widget teacher;
  final Widget parent;
  final Widget admin;
  final Widget driver;

  const RoleSwitch({
    super.key,
    required this.student,
    required this.teacher,
    required this.parent,
    required this.admin,
    required this.driver,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(currentUserProvider).role) {
      case UserRole.student:
        return student;
      case UserRole.teacher:
        return teacher;
      case UserRole.parent:
        return parent;
      case UserRole.admin:
        return admin;
      case UserRole.driver:
        return driver;
    }
  }
}
