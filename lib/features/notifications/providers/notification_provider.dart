import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../data/demo_notifier.dart';
import '../models/notification_model.dart';
import '../repo/api_notification_repository.dart';
import '../repo/mock_notification_repository.dart';
import '../repo/notification_repository.dart';

/// Test mode: live notifications created on this device (bus, reminders).
final demoNotifierProvider = ChangeNotifierProvider<DemoNotifier>(
  (ref) => DemoNotifier(),
);

/// The server when API_URL is set, otherwise sample notifications.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => AppConfig.useApi
      ? ApiNotificationRepository(watchApi(ref), ref.read(demoNotifierProvider))
      : MockNotificationRepository(demo: ref.read(demoNotifierProvider)),
);

/// With the server: look for new notifications every 15 seconds while the live
/// connection is down, so the banner shows while the app is open (Web Push
/// covers it when closed).
final _notificationCheckProvider = StreamProvider<int>((ref) {
  if (!AppConfig.useApi) return const Stream.empty();
  return Stream.periodic(const Duration(seconds: 15), (i) => i).where((i) {
    final live = ref.read(realtimeClientProvider)?.isConnected ?? false;
    return !live || i % 8 == 0;
  });
});

final notificationsProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  // Reload whenever a live (test mode) notification arrives, and on the
  // server's 15-second check.
  ref.watch(demoNotifierProvider);
  ref.watch(_notificationCheckProvider);
  final user = ref.watch(currentUserProvider);
  final all = await ref.watch(notificationRepositoryProvider).getAll(user.id);

  // Drivers just drive: they only hear about their bus.
  if (user.role == UserRole.driver) {
    return all.where((n) => n.type == NotificationType.transport).toList();
  }
  return all;
});

/// For the dot on the bell icon.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? [];

  return items.where((n) => !n.isRead).length;
});

final markNotificationReadProvider = Provider<Future<void> Function(String id)>(
  (ref) => (id) async {
    await ref.read(notificationRepositoryProvider).markAsRead(id);
    ref.invalidate(notificationsProvider);
  },
);

final markAllNotificationsReadProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    ref.invalidate(notificationsProvider);
  },
);
