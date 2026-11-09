import '../data/demo_notifier.dart';
import '../data/mock_notifications.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

/// Sample notifications plus live ones from [DemoNotifier] (test mode).
class MockNotificationRepository implements NotificationRepository {
  final DemoNotifier demo;

  MockNotificationRepository({required this.demo});

  /// User ID → that user's sample notifications (kept so "mark as read" sticks).
  final Map<String, List<NotificationModel>> _byUser = {};

  /// The user whose list was loaded last. The real API knows the user
  /// from the session; the mock remembers it here.
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

  /// Test mode has no server to send them from.
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
