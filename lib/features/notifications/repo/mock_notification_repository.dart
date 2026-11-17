import '../data/demo_notifier.dart';
import '../data/mock_notifications.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  final DemoNotifier demo;

  MockNotificationRepository({required this.demo});

  final Map<String, List<NotificationModel>> _byUser = {};

  String _currentUserId = '';

  List<NotificationModel> get _samples => _byUser.putIfAbsent(
    _currentUserId,
    () => MockNotifications.forUser(_currentUserId),
  );

  @override
  Future<List<NotificationModel>> getAll(String userId) async {
    _currentUserId = userId;

    return [..._samples, ...demo.itemsFor(userId)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _samples.indexWhere((n) => n.id == id);
    if (index != -1) _samples[index] = _samples[index].markedRead();

    demo.markRead(_currentUserId, id);
  }

  @override
  Future<bool> turnOnPhoneNotifications() async => false;

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _samples.length; i++) {
      _samples[i] = _samples[i].markedRead();
    }

    demo.markAllRead(_currentUserId);
  }

  @override
  Future<void> registerThisPhone([String? id]) async {}

  @override
  Future<void> forgetThisPhone() async {}
}
