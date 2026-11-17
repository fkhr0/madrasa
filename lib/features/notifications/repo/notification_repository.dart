import '../models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getAll(String userId);

  Future<void> markAsRead(String id);

  Future<void> markAllAsRead();

  Future<bool> turnOnPhoneNotifications() async => false;

  Future<void> registerThisPhone([String? token]) async {}

  Future<void> forgetThisPhone() async {}
}
