import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/planner_provider.dart';
import 'plan_tip_tile.dart';
import '../../../core/l10n/language.dart';

/// The top planner tips on a home page, with a link to the full plan.
/// Shows a calm "all caught up" card when there is nothing to do.
class ForYouSection extends ConsumerWidget {
  final int maxItems;

  const ForYouSection({super.key, this.maxItems = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = ref.watch(currentUserProvider).role == UserRole.student;
    final tips = ref.watch(planTipsProvider).valueOrNull;
    if (tips == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: tr('For you'),
          onSeeAll: tips.length > maxItems
              ? () => context.push(AppRoutes.planner)
              : null,
        ),
        if (tips.isEmpty)
          AppCard(
            child: Row(
              children: [
                const IconBox(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    tr('You\'re all caught up. Nothing needs you right now.'),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        for (final tip in tips.take(maxItems)) ...[
          PlanTipTile(tip: tip, canRemind: isStudent),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
