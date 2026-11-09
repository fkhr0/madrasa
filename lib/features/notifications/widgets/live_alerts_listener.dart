import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/push/web_push.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/open_route.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../../../core/l10n/language.dart';

/// Wraps the signed-in app and.
class LiveAlertsListener extends ConsumerStatefulWidget {
  final Widget child;

  const LiveAlertsListener({super.key, required this.child});

  @override
  ConsumerState<LiveAlertsListener> createState() => _LiveAlertsListenerState();
}

class _LiveAlertsListenerState extends ConsumerState<LiveAlertsListener> {
  /// Only reminders due after sign-in fire (no burst of old ones).
  final DateTime _since = DateTime.now();
  final Set<String> _firedReminders = {};

  /// Mock mode only: with the server, the "reminders.tasks" job sends them
  /// (as a notification, and a push when the app is closed).
  void _checkReminders(DateTime now) {
    if (AppConfig.useApi) return;
    final user = ref.read(currentUserProvider);
    final tasks = ref.read(tasksProvider).valueOrNull ?? const <TaskModel>[];

    for (final task in tasks) {
      final isDue =
          task.isReminder &&
          !task.isDone &&
          !task.dueAt.isAfter(now) &&
          task.dueAt.isAfter(_since);

      if (!isDue || !_firedReminders.add(task.id)) continue;

      ref.read(demoNotifierProvider).notify(
        [user.id],
        NotificationModel(
          id: 'reminder-${task.id}',
          type: NotificationType.reminder,
          title: task.title,
          body: tr('Reminder · {0}', [DateFormatter.time(task.dueAt)]),
          createdAt: now,
          route: task.route ?? AppRoutes.tasks,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (AppConfig.useApi && webPushPermission == 'granted') {
      ref
          .read(notificationRepositoryProvider)
          .turnOnPhoneNotifications()
          .catchError((_) => false);
    }
  }

  void _showBanner(NotificationModel n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Icon(n.type.icon, color: n.type.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(n.body),
                  ],
                ),
              ),
            ],
          ),
          action: n.route == null
              ? null
              : SnackBarAction(
                  label: tr('View'),
                  onPressed: () => context.openRoute(n.route!),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref.watch(currentUserProvider).role == UserRole.student;

    // Keep the student's tasks loaded so reminders can fire.
    if (isStudent) ref.watch(tasksProvider);

    ref.listen(nowProvider, (_, now) {
      if (isStudent) _checkReminders(now);
    });

    ref.listen(notificationsProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null) return; // first load: no banners

      final known = {for (final n in before) n.id};
      final fresh = after.where((n) => !known.contains(n.id) && !n.isRead);
      if (fresh.isNotEmpty) _showBanner(fresh.first);
    });

    return widget.child;
  }
}
