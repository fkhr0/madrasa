import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../subjects/data/mock_subjects.dart';
import '../providers/resource_provider.dart';
import '../widgets/resource_tile.dart';
import '../../../core/l10n/language.dart';

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(filteredResourcesProvider);
    final selectedSubject = ref.watch(resourceSubjectProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Learning resources'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: (v) =>
                  ref.read(resourceSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: tr('Search materials'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // Subject filter chips.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                _chip(
                  ref,
                  label: tr('All'),
                  subjectId: null,
                  selected: selectedSubject,
                ),
                // Subjects come from the backend in a later stage.
                for (final subject in MockSubjects.all)
                  _chip(
                    ref,
                    label: subject.name,
                    subjectId: subject.id,
                    selected: selectedSubject,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: AsyncValueView(
              value: resources,
              onRetry: () => ref.invalidate(resourcesProvider),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: tr('No materials found'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => ResourceTile(resource: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    WidgetRef ref, {
    required String label,
    required String? subjectId,
    required String? selected,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: subjectId == selected,
        onSelected: (_) =>
            ref.read(resourceSubjectProvider.notifier).state = subjectId,
      ),
    );
  }
}
