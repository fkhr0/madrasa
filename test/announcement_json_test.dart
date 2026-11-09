import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/announcements/models/announcement_model.dart';

void main() {
  test('announcement JSON matches the server', () {
    final a = AnnouncementModel.fromJson({
      'id': 'a1',
      'title': 'Quiz on Sunday',
      'body': 'Chapter 4.',
      'audience': 'class',
      'className': '5th Scientific – A',
      'authorId': 'TCH-2019-0031',
      'authorName': 'Ahmed Kareem',
      'publishedAt': '2026-11-05T08:00:00.000Z',
      'isPinned': false,
    });

    expect(a.audience, AnnouncementAudience.className);
    expect(a.isWrittenBy('TCH-2019-0031', 'Someone else'), isTrue);
    expect(a.toJson()['audience'], 'class');
    // Already published: no publishedAt, so the server uses its own clock.
    expect(a.toJson().containsKey('publishedAt'), isFalse);

    final scheduled = a.copyWith(
      publishedAt: DateTime.now().add(const Duration(days: 1)),
    );
    expect(scheduled.toJson()['publishedAt'], endsWith('Z'));
  });
}
