import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../../core/l10n/language.dart';

/// One row in the People list: name, ID, class / subject, and a badge
/// when the account is deactivated.
class PersonTile extends StatelessWidget {
  final UserModel person;

  const PersonTile({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: () => context.push(AppRoutes.personDetails(person.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Opacity(
              opacity: person.isActive ? 1 : 0.4,
              child: UserAvatar(name: person.name),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: context.text.titleSmall),
                  Text(
                    '${person.id} · ${person.roleDetail}',
                    style: context.text.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!person.isActive)
              StatusBadge(label: tr('Inactive'), color: AppColors.neutral)
            else
              Icon(Icons.chevron_right, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}
