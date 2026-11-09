import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/teaching_class_model.dart';
import '../../../core/l10n/language.dart';

class ClassCard extends StatelessWidget {
  final TeachingClassModel teachingClass;

  const ClassCard({super.key, required this.teachingClass});

  @override
  Widget build(BuildContext context) {
    final c = teachingClass;

    return AppCard(
      onTap: () => context.push(AppRoutes.classDetails(c.id)),
      child: Row(
        children: [
          IconBox(icon: Icons.groups_outlined, color: c.subject.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  tr('{0} · {1} students · {2}', [
                    c.subject.name,
                    c.studentCount,
                    c.room,
                  ]),
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (c.toGradeCount > 0)
            StatusBadge(
              label: tr('{0} to grade', [c.toGradeCount]),
              color: AppColors.warning,
            )
          else
            Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}
