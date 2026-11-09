import '../models/notification_model.dart';

/// MockNotificationRepository (no server) or ApiNotificationRepository.
abstract class NotificationRepository {
  /// Notifications of [userId], newest first.
  Future<List<NotificationModel>> getAll(String userId);

  Future<void> markAsRead(String id);

  Future<void> markAllAsRead();

  /// Asks to show notifications on this phone while the app is closed.
  /// False when the person said no or the browser can't.
  Future<bool> turnOnPhoneNotifications() async => false;

  /// Android app, already allowed: tells the server this phone's token
  /// (after signing in, and when Firebase changes it).
  Future<void> registerThisPhone([String? token]) async {}

  /// Signing out: this phone stops getting this person's notifications.
  Future<void> forgetThisPhone() async {}
}
