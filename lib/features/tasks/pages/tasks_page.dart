import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/reminder_sheet.dart';
import '../widgets/task_tile.dart';
import '../../../core/l10n/language.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Tasks and reminders'))),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'reminder',
            tooltip: tr('New reminder'),
            onPressed: () => showReminderSheet(context),
            child: const Icon(Icons.alarm_add),
          ),
          const SizedBox(height: AppSpacing.md),
          FloatingActionButton.extended(
            heroTag: 'task',
            onPressed: () => showAddTaskSheet(context),
            icon: const Icon(Icons.add),
            label: Text(tr('New task')),
          ),
        ],
      ),
      body: AsyncValueView(
        value: tasks,
        onRetry: () => ref.invalidate(tasksProvider),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.checklist,
              title: tr('No tasks yet'),
              message: tr(
                'Add reminders for anything you don\'t want to forget.',
              ),
            );
          }

          final now = DateTime.now();
          final open = tasks.where((t) => !t.isDone).toList();

          final groups = <String, List<TaskModel>>{
            'Overdue': open.where((t) => t.isOverdue).toList(),
            'Today': open
                .where(
                  (t) => !t.isOverdue && DateFormatter.isSameDay(t.dueAt, now),
                )
                .toList(),
            'Coming up': open
                .where(
                  (t) => !t.isOverdue && !DateFormatter.isSameDay(t.dueAt, now),
                )
                .toList(),
            'Done': tasks.where((t) => t.isDone).toList(),
          };

          return ListView(
            // Extra bottom space so the button never hides the last task.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              150,
            ),
            children: [
              for (final group in groups.entries)
                if (group.value.isNotEmpty) ...[
                  SectionHeader(title: '${group.key} (${group.value.length})'),
                  for (final task in group.value) ...[
                    TaskTile(task: task),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}
