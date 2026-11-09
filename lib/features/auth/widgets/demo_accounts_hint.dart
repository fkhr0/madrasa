import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../data/mock_users.dart';
import '../../../core/l10n/language.dart';

/// DEMO BUILD ONLY, remove when the real backend is connected.
/// Lists the test accounts; tapping one fills the ID field.
class DemoAccountsHint extends StatelessWidget {
  final ValueChanged<String> onPick;

  const DemoAccountsHint({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.palette.cardMuted,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConfig.useApi
                ? tr('Demo accounts (password: demo1234)')
                : tr('Demo accounts (any password, 4+ characters)'),
            style: context.text.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final user in MockUsers.demoAccounts)
                ActionChip(
                  label: Text(user.role.label),
                  onPressed: () => onPick(user.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
