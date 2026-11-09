import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/plan_tip_model.dart';
import '../providers/planner_provider.dart';
import '../widgets/plan_tip_tile.dart';
import '../../../core/l10n/language.dart';

/// The full plan, grouped Today / Tomorrow / This week (doc §3.21).
class PlannerPage extends ConsumerWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = ref.watch(currentUserProvider).role == UserRole.student;
    final tips = ref.watch(planTipsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('My plan'))),
      body: AsyncValueView(
        value: tips,
        onRetry: () => ref.invalidate(planTipsProvider),
        data: (tips) {
          if (tips.isEmpty) {
            return EmptyState(
              icon: Icons.self_improvement,
              title: tr('All caught up'),
              message: tr('Nothing to plan for the coming days.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              for (final when in PlanWhen.values)
                if (tips.any((t) => t.when == when)) ...[
                  SectionHeader(title: when.label),
                  for (final tip in tips.where((t) => t.when == when)) ...[
                    PlanTipTile(tip: tip, canRemind: isStudent),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}
