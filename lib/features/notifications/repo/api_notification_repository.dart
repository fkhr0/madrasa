import 'package:flutter/foundation.dart';

import '../../../core/l10n/language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/phone_push.dart';
import '../../../core/push/web_push.dart';
import '../data/demo_notifier.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

/// Notifications from the school API (server/src/features/notifications),
/// plus the reminders this device fires itself (they live on the phone).
class ApiNotificationRepository implements NotificationRepository {
  final ApiClient _api;
  final DemoNotifier _local;

  ApiNotificationRepository(this._api, this._local);

  String _userId = '';

  @override
  Future<List<NotificationModel>> getAll(String userId) async {
    _userId = userId;
    final list = await _api.get('/notifications') as List;
    return [
      for (final json in list)
        NotificationModel.fromJson(json as Map<String, dynamic>),
      ..._local.itemsFor(userId),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAsRead(String id) async {
    if (_local.itemsFor(_userId).any((n) => n.id == id)) {
      _local.markRead(_userId, id);
      return;
    }
    await _api.post('/notifications/$id/read');
  }

  @override
  Future<void> markAllAsRead() async {
    _local.markAllRead(_userId);
    await _api.post('/notifications/read-all');
  }

  @override
  Future<bool> turnOnPhoneNotifications() async {
    // The Android app: Firebase.
    if (PhonePush.supported) {
      final id = await PhonePush.askAndGetId();
      if (id == null) return false;
      await registerThisPhone(id);
      return true;
    }
    // The browser: Web Push.
    final key = await _api.get('/notifications/push-key') as Map;
    final subscription = await subscribeToWebPush(key['publicKey'] as String);
    if (subscription == null) return false;
    await _api.post('/notifications/push', {
      ...subscription,
      'language': AppLanguage.current.name,
    });
    return true;
  }

  @override
  Future<void> registerThisPhone([String? id]) async {
    // The browser, already allowed: the same subscription again, with the
    // app's language now (the server sends pushes in it).
    if (kIsWeb) {
      if (webPushPermission == 'granted') await turnOnPhoneNotifications();
      return;
    }
    id ??= await PhonePush.idIfAllowed();
    if (id == null) return;
    await _api.post('/notifications/devices', {
      'token': id,
      'platform': 'android',
      'language': AppLanguage.current.name,
    });
  }

  @override
  Future<void> forgetThisPhone() async {
    if (!PhonePush.supported) return;
    final id = PhonePush.lastId;
    try {
      if (id != null) {
        await _api.delete('/notifications/devices', {'token': id});
      }
    } finally {
      await PhonePush.forget();
    }
  }
}
