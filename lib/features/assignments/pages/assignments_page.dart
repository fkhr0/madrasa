import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/assignment_provider.dart';
import '../widgets/assignment_filter_bar.dart';
import '../widgets/assignment_tile.dart';
import '../../../core/l10n/language.dart';

class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(filteredAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Assignments'))),
      body: Column(
        children: [
          const AssignmentFilterBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView(
              value: assignments,
              onRetry: () => ref.invalidate(assignmentsProvider),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.task_alt,
                    title: tr('Nothing here'),
                    message: tr('No assignments match this filter.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(assignmentsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      AppSpacing.xl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => AssignmentTile(assignment: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
