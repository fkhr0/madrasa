import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/people_provider.dart';
import '../widgets/person_tile.dart';
import '../widgets/role_chips.dart';
import '../../../core/l10n/language.dart';

/// Administrator's directory of students, teachers and parents.
class PeoplePage extends ConsumerWidget {
  const PeoplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(peopleRoleProvider);
    final people = ref.watch(filteredPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('People'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addPerson),
        icon: const Icon(Icons.person_add_alt),
        label: Text(tr('Add')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: RoleChips(
              plural: true,
              selected: role,
              onSelected: (r) =>
                  ref.read(peopleRoleProvider.notifier).state = r,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: TextField(
              onChanged: (v) =>
                  ref.read(peopleSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: tr('Search by name, ID or class'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: people,
              onRetry: () => ref.invalidate(peopleByRoleProvider(role)),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_outlined,
                    title: tr('No one found'),
                  );
                }

                return ListView.separated(
                  // Room for the floating button.
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    indent: AppSpacing.page + 52,
                    endIndent: AppSpacing.page,
                  ),
                  itemBuilder: (_, i) => PersonTile(person: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
