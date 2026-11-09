import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/school_class_model.dart';
import '../../../core/l10n/language.dart';

class SchoolClassTile extends StatelessWidget {
  final SchoolClassModel schoolClass;

  const SchoolClassTile({super.key, required this.schoolClass});

  @override
  Widget build(BuildContext context) {
    final c = schoolClass;

    return AppCard(
      onTap: () => context.push(AppRoutes.schoolClass(c.id)),
      child: Row(
        children: [
          IconBox(icon: Icons.groups_outlined, color: context.palette.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: context.text.titleSmall),
                Text(
                  tr('{0} students · {1}', [
                    c.studentCount,
                    c.homeroomTeacherName ?? tr('no head teacher yet'),
                  ]),
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (c.unassignedCount > 0)
            StatusBadge(
              label: tr('{0} need a teacher', [c.unassignedCount]),
              color: AppColors.warning,
            )
          else
            Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
