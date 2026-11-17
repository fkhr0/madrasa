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

final demoNotifierProvider = ChangeNotifierProvider<DemoNotifier>(
  (ref) => DemoNotifier(),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => AppConfig.useApi
      ? ApiNotificationRepository(watchApi(ref), ref.read(demoNotifierProvider))
      : MockNotificationRepository(demo: ref.read(demoNotifierProvider)),
);

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
  ref.watch(demoNotifierProvider);
  ref.watch(_notificationCheckProvider);
  final user = ref.watch(currentUserProvider);
  final all = await ref.watch(notificationRepositoryProvider).getAll(user.id);

  if (user.role == UserRole.driver) {
    return all.where((n) => n.type == NotificationType.transport).toList();
  }
  return all;
});

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
