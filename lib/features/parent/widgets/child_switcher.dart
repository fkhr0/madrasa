import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// One chip per child. Picking a child refreshes every screen
/// (grades, attendance, schedule...) for that child.
/// Hidden when the parent has only one child.
class ChildSwitcher extends ConsumerWidget {
  const ChildSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(currentUserProvider).children;
    final selected = ref.watch(activeStudentProvider);
    final palette = context.palette;

    if (children.length < 2) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: Material(
                color: children[i].id == selected?.id
                    ? palette.primarySoft
                    : palette.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  side: BorderSide(
                    color: children[i].id == selected?.id
                        ? palette.primary
                        : palette.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () =>
                      ref.read(selectedChildIndexProvider.notifier).state = i,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 14, 4),
                    child: Row(
                      children: [
                        UserAvatar(name: children[i].name, size: 30),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          children[i].firstName,
                          style: context.text.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
