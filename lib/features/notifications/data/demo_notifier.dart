import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

/// TEST MODE ONLY, stands in for the server's notification jobs (BullMQ + push,
/// see docs/PLATFORM_PLAN.md §3).
class DemoNotifier extends ChangeNotifier {
  final Map<String, List<NotificationModel>> _byUser = {};

  List<NotificationModel> itemsFor(String userId) => _byUser[userId] ?? [];

  void notify(Iterable<String> userIds, NotificationModel notification) {
    for (final userId in userIds.toSet()) {
      _byUser.putIfAbsent(userId, () => []).add(notification);
    }
    notifyListeners();
  }

  void markRead(String userId, String notificationId) {
    final items = _byUser[userId];
    if (items == null) return;

    final index = items.indexWhere((n) => n.id == notificationId);
    if (index != -1) items[index] = items[index].markedRead();
  }

  void markAllRead(String userId) {
    final items = _byUser[userId];
    if (items == null) return;

    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].markedRead();
    }
  }
}
