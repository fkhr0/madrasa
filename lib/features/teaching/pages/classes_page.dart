import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/teaching_provider.dart';
import '../widgets/class_card.dart';
import '../../../core/l10n/language.dart';

class ClassesPage extends ConsumerWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(myClassesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('My classes'))),
      body: AsyncValueView(
        value: classes,
        onRetry: () => ref.invalidate(myClassesProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: tr('No classes yet'),
              message: tr('The school administration assigns classes to you.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => ClassCard(teachingClass: items[i]),
          );
        },
      ),
    );
  }
}
