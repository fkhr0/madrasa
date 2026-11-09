import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/messages/models/conversation_model.dart';
import 'package:school/features/messages/models/message_model.dart';
import 'package:school/features/messages/repo/mock_message_repository.dart';

void main() {
  test('a group chat shows who wrote the last message', () {
    final group = ConversationModel.fromJson({
      'id': 'c1',
      'title': '5th Scientific – A',
      'subtitle': 'Class chat',
      'isGroup': true,
      'lastMessage': 'Lab coats on Thursday',
      'lastSender': 'Omar Saleh',
      'lastMessageAt': '2026-11-08T07:00:00.000Z',
      'unreadCount': 2,
    });
    expect(group.lastMessage, 'Omar: Lab coats on Thursday');
    expect(group.unreadCount, 2);

    final message = MessageModel.fromJson({
      'id': 'm1',
      'senderName': 'Ahmed Kareem',
      'text': 'Hello',
      'sentAt': '2026-11-08T07:00:00.000Z',
      'isMine': true,
    }, conversationId: 'c1');
    expect(message.isMine, isTrue);
    expect(message.conversationId, 'c1');
  });

  test('mock: starting a chat twice opens the same one', () async {
    final repo = MockMessageRepository();
    final contacts = await repo.getContacts();

    final first = await repo.startConversation(contacts.first.id);
    final again = await repo.startConversation(contacts.first.id);
    expect(again, first);

    await repo.sendMessage(first, 'Hello');
    final chats = await repo.getConversations('STU-2026-0142');
    expect(chats.firstWhere((c) => c.id == first).lastMessage, 'Hello');
  });
}
