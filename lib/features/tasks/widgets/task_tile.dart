import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../../../core/l10n/language.dart';

/// Tap the circle to tick it off, swipe left to delete.
class TaskTile extends ConsumerWidget {
  final TaskModel task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final controller = ref.read(tasksProvider.notifier);

    final dueColor = task.isOverdue ? AppColors.danger : palette.textSecondary;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      // Swiping only asks; the task goes away after "Delete".
      confirmDismiss: (_) => confirmDelete(
        context,
        title: task.isReminder
            ? tr('Delete this reminder?')
            : tr('Delete this task?'),
        message: '"${task.title}"',
      ),
      onDismissed: (_) {
        controller.delete(task);
        context.showMessage(tr('Task deleted'));
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: AppCard(
        onTap: () => controller.toggle(task),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _CheckCircle(checked: task.isDone, color: task.priority.color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Opacity(
                opacity: task.isDone ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: context.text.titleSmall?.copyWith(
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.note != null)
                      Text(
                        task.note!,
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: dueColor),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            '${DateFormatter.relativeDay(task.dueAt)}, '
                            '${DateFormatter.time(task.dueAt)}',
                            style: context.text.labelSmall?.copyWith(
                              color: dueColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.isReminder) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(Icons.alarm, size: 13, color: palette.textMuted),
                        ],
                        if (task.repeat != TaskRepeat.none) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.repeat,
                            size: 13,
                            color: palette.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round checkbox in the colour of the task's priority.
class _CheckCircle extends StatelessWidget {
  final bool checked;
  final Color color;

  const _CheckCircle({required this.checked, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
