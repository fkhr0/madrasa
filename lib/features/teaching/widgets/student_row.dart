import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/grade_scale.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/class_student_model.dart';
import '../../../core/l10n/language.dart';

/// Student name with their average and attendance in this class.
class StudentRow extends StatelessWidget {
  final ClassStudentModel student;

  const StudentRow({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          UserAvatar(name: student.name, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: context.text.titleSmall),
                Text(
                  switch (student.attendanceRate) {
                    final rate? => tr('Attendance {0}%', [rate.round()]),
                    null => tr('No attendance yet'),
                  },
                  style: context.text.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (student.average case final average?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${average.round()}',
                  style: context.text.titleMedium?.copyWith(
                    color: GradeScale.colorFor(average),
                  ),
                ),
                Text(
                  GradeScale.labelFor(average),
                  style: context.text.labelSmall,
                ),
              ],
            )
          else
            Text('–', style: context.text.titleMedium),
        ],
      ),
    );
  }
}
