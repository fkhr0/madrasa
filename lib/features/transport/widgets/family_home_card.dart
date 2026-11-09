import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../providers/transport_provider.dart';
import 'home_location_sheet.dart';
import '../../../core/l10n/language.dart';

/// Parent: share (or update) the home, so the school can pick the child up
/// at the door. Saves the family sending it on WhatsApp.
class FamilyHomeCard extends ConsumerWidget {
  final String studentId;
  final String firstName;

  const FamilyHomeCard({
    super.key,
    required this.studentId,
    required this.firstName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(studentHomeProvider(studentId)).valueOrNull;

    return AppCard(
      onTap: () async {
        final saved = await showHomeLocationSheet(
          context,
          studentId: studentId,
          firstName: firstName,
          isFamily: true,
        );
        if (saved != null && context.mounted) {
          context.showMessage(tr('Home shared with the school'));
        }
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBox(
            icon: home == null ? Icons.add_home_outlined : Icons.home_outlined,
            color: home == null ? AppColors.info : AppColors.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  home == null
                      ? tr('Share your home')
                      : tr('Home shared with school'),
                  style: context.text.titleSmall,
                ),
                Text(
                  home == null
                      ? tr('For door-to-door pick-up of {0}', [firstName])
                      : home.note.isEmpty
                      ? tr('Tap to move it')
                      : tr('"{0}" · tap to change', [home.note]),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
