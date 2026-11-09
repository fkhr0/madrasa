import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/menu_tile.dart';
import '../providers/teaching_provider.dart';
import '../../../core/l10n/language.dart';

/// Asks "Which class?" and then opens [routeFor] of the chosen class.
/// Used by the teacher's quick actions on the home page.
Future<void> showClassPicker(
  BuildContext context, {
  required String title,
  required String Function(String classId) routeFor,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final classes = ref.watch(myClassesProvider).valueOrNull ?? [];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: Text(title, style: context.text.titleLarge),
              ),
              for (final c in classes)
                MenuTile(
                  icon: Icons.groups_outlined,
                  iconColor: c.subject.color,
                  title: c.name,
                  subtitle: tr('{0} students · {1}', [c.studentCount, c.room]),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push(routeFor(c.id));
                  },
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    ),
  );
}
