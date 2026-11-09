import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/push/web_push.dart';
import 'package:school/features/notifications/models/notification_model.dart';

void main() {
  test('notifications from the server', () {
    final n = NotificationModel.fromJson({
      'id': 'n1',
      'type': 'transport',
      'title': 'Bus 12 is about 4 min away',
      'body': 'Please be ready at Al-Yarmouk',
      'route': '/bus',
      'createdAt': '2026-11-05T05:20:00.000Z',
      'isRead': false,
    });
    expect(n.type, NotificationType.transport);
    expect(n.route, '/bus');
    expect(n.isRead, isFalse);

    // A kind this app version doesn't know yet still shows.
    final unknown = NotificationModel.fromJson({
      'id': 'n2',
      'type': 'something-new',
      'title': 'Hi',
      'createdAt': '2026-11-05T05:20:00.000Z',
    });
    expect(unknown.type, NotificationType.announcement);
  });

  test('outside a browser there is no Web Push', () async {
    expect(webPushSupported, isFalse);
    expect(await subscribeToWebPush('key'), isNull);
  });
}
