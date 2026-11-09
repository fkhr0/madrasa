import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/language.dart';
import '../../../core/utils/context_extensions.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../repo/auth_repository.dart';

/// "Try the app": opens the demo school as a student, parent, teacher, the
/// office or the bus driver, without an account. Shown only when the server
/// has a demo (DEMO_MODE).
class TryDemoButton extends ConsumerWidget {
  const TryDemoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(demoRolesProvider).valueOrNull ?? const [];
    if (roles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: OutlinedButton.icon(
        onPressed: () => _chooseRole(context, ref, roles),
        icon: const Icon(Icons.play_circle_outline),
        label: Text(tr('Try the app')),
      ),
    );
  }

  Future<void> _chooseRole(
    BuildContext context,
    WidgetRef ref,
    List<UserRole> roles,
  ) async {
    final role = await showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Try the app as…'), style: context.text.titleLarge),
                  Text(
                    tr(
                      'A demo school with sample data. Look around freely: it goes back to how it was every night.',
                    ),
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            for (final role in roles)
              ListTile(
                leading: Icon(_icons[role]),
                title: Text(role.label),
                subtitle: Text(_whatTheySee[role] ?? ''),
                onTap: () => Navigator.pop(context, role),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (role == null || !context.mounted) return;
    try {
      await ref.read(authProvider.notifier).signInDemo(role);
    } on AuthException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  static const _icons = {
    UserRole.student: Icons.school_outlined,
    UserRole.parent: Icons.family_restroom_outlined,
    UserRole.teacher: Icons.co_present_outlined,
    UserRole.admin: Icons.admin_panel_settings_outlined,
    UserRole.driver: Icons.directions_bus_outlined,
  };

  static Map<UserRole, String> get _whatTheySee => {
    UserRole.student: tr('Timetable, homework, exams and grades'),
    UserRole.parent: tr('Two children, attendance, fees and the bus'),
    UserRole.teacher: tr('Classes, attendance and grading'),
    UserRole.admin: tr('The whole school today, people and settings'),
    UserRole.driver: tr('Trips, stops and who is on board'),
  };
}
