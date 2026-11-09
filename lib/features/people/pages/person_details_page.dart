import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../transport/providers/transport_provider.dart';
import '../models/account_credentials_model.dart';
import '../providers/people_provider.dart';
import '../widgets/credentials_sheet.dart';
import '../../../core/l10n/language.dart';

/// Administrator's view of one account: details and account actions.
class PersonDetailsPage extends ConsumerWidget {
  final String personId;

  const PersonDetailsPage({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personByIdProvider(personId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (person.valueOrNull != null)
            IconButton(
              tooltip: tr('Edit'),
              onPressed: () => context.push(AppRoutes.editPerson(personId)),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AsyncValueView(
        value: person,
        data: (person) {
          if (person == null) {
            return EmptyState(
              icon: Icons.person_off_outlined,
              title: tr('Account not found'),
            );
          }

          return _Content(person: person);
        },
      ),
    );
  }
}

/// "Bus 12 · Al-Mansour line", or a hint when the driver has no bus.
String _busOf(WidgetRef ref, String driverId) {
  for (final r in ref.watch(busRoutesProvider).valueOrNull ?? const []) {
    if (r.driverId == driverId) {
      return tr('Bus {0} · {1}', [r.busNumber, r.name]);
    }
  }

  return tr('No bus yet (assign in Transport)');
}

class _Content extends ConsumerWidget {
  final UserModel person;

  const _Content({required this.person});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete {0}\'s account?', [person.firstName])),
        content: Text(
          tr(
            'Use this for mistakes, like a duplicate account. For someone who left the school, deactivate the account instead so their history is kept. This can\'t be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(peopleActionsProvider).delete(person);
      if (!context.mounted) return;
      context.showMessage(tr('{0} deleted', [person.name]));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final AccountCredentialsModel credentials;
    try {
      credentials = await ref.read(peopleActionsProvider).resetPassword(person);
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
      return;
    }
    if (!context.mounted) return;

    await showCredentialsSheet(
      context,
      credentials,
      title: tr('New temporary password'),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final activate = !person.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          activate ? tr('Activate account?') : tr('Deactivate account?'),
        ),
        content: Text(
          activate
              ? tr('{0} will be able to sign in again.', [person.firstName])
              : tr(
                  '{0} will not be able to sign in. Grades, attendance and messages are kept.',
                  [person.firstName],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: activate ? null : AppColors.danger,
            ),
            child: Text(activate ? tr('Activate') : tr('Deactivate')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(peopleActionsProvider).setActive(person, activate);
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: UserAvatar(name: person.name, size: AppSizes.avatarLg),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          person.name,
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        Text(
          person.roleDetail,
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: person.isActive
              ? StatusBadge(label: tr('Active'), color: AppColors.success)
              : StatusBadge(label: tr('Inactive'), color: AppColors.neutral),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.badge_outlined,
                label: tr('School ID'),
                value: person.id,
              ),
              InfoRow(
                icon: Icons.person_outline,
                label: tr('Role'),
                value: person.role.label,
              ),
              if (person.email.isNotEmpty)
                InfoRow(
                  icon: Icons.alternate_email,
                  label: tr('Email'),
                  value: person.email,
                ),
              if (person.phone.isNotEmpty)
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: tr('Phone'),
                  value: person.phone,
                ),
              for (final child in person.children)
                InfoRow(
                  icon: Icons.child_care_outlined,
                  label: tr('Child'),
                  value: child.name,
                ),
              if (person.role == UserRole.driver)
                InfoRow(
                  icon: Icons.directions_bus_outlined,
                  label: tr('Drives'),
                  value: _busOf(ref, person.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (person.role == UserRole.student) ...[
          MenuGroup(
            title: tr('School'),
            children: [
              MenuTile(
                icon: Icons.fact_check_outlined,
                title: tr('Attendance'),
                subtitle: tr('This term, and excused days'),
                onTap: () =>
                    context.push(AppRoutes.personAttendance(person.id)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        MenuGroup(
          title: tr('Account'),
          children: [
            MenuTile(
              icon: Icons.lock_reset,
              title: tr('Reset password'),
              subtitle: tr('Creates a new temporary password'),
              onTap: () => _resetPassword(context, ref),
            ),
            MenuTile(
              icon: person.isActive
                  ? Icons.block_outlined
                  : Icons.check_circle_outline,
              title: person.isActive
                  ? tr('Deactivate account')
                  : tr('Activate account'),
              color: person.isActive ? AppColors.danger : AppColors.success,
              trailing: const SizedBox.shrink(),
              onTap: () => _toggleActive(context, ref),
            ),
            MenuTile(
              icon: Icons.delete_outline,
              title: tr('Delete account'),
              subtitle: tr('Only for mistakes, like a duplicate'),
              color: AppColors.danger,
              trailing: const SizedBox.shrink(),
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
