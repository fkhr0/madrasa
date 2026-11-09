import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../models/assignment_filter.dart';
import '../providers/assignment_provider.dart';

/// Horizontal row of filter chips (All / To do / Submitted / Graded).
class AssignmentFilterBar extends ConsumerWidget {
  const AssignmentFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(assignmentFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final filter in AssignmentFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: filter == selected,
                onSelected: (_) =>
                    ref.read(assignmentFilterProvider.notifier).state = filter,
              ),
            ),
        ],
      ),
    );
  }
}
