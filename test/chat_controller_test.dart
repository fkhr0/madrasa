import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/network/api_exception.dart';
import 'package:school/features/messages/models/conversation_model.dart';
import 'package:school/features/messages/models/message_model.dart';
import 'package:school/features/messages/providers/message_provider.dart';
import 'package:school/features/messages/repo/message_repository.dart';

/// A server we control: how slow it answers, and whether it fails.
class FakeChatServer implements MessageRepository {
  final messages = <MessageModel>[];
  Completer<void>? hold;
  bool offline = false;
  int loads = 0;

  MessageModel _message(String text, {bool mine = true}) => MessageModel(
    id: 'm${messages.length + 1}',
    conversationId: 'c1',
    senderName: mine ? 'Me' : 'Ahmed',
    text: text,
    sentAt: DateTime(2026, 11, 9, 10, messages.length),
    isMine: mine,
    status: MessageStatus.sent,
  );

  void receive(String text) => messages.add(_message(text, mine: false));

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? after,
  }) async {
    loads++;
    return messages
        .where((m) => after == null || m.sentAt.isAfter(after))
        .toList();
  }

  @override
  Future<MessageModel> sendMessage(String conversationId, String text) async {
    if (offline) throw const ApiException('Can\'t reach the server.');
    // Like the real server: saved first, the answer may come later.
    final message = _message(text);
    messages.add(message);
    await hold?.future;
    return message;
  }

  @override
  Future<MessageModel> editMessage(MessageModel message, String text) async =>
      message.copyWith(text: text, edited: true);

  @override
  Future<void> deleteMessage(MessageModel message) async {}

  @override
  Future<void> markAsRead(String conversationId) async {}

  @override
  Future<List<ConversationModel>> getConversations(String userId) async => [];

  @override
  Future<List<ContactModel>> getContacts() async => [];

  @override
  Future<String> startConversation(String userId) async => 'c1';
}

void main() {
  late FakeChatServer server;
  late ProviderContainer container;
  List<MessageModel> chat() => container.read(chatProvider('c1')).value!;
  ChatController controller() => container.read(chatProvider('c1').notifier);

  setUp(() async {
    server = FakeChatServer()..receive('Hello');
    container = ProviderContainer(
      overrides: [messageRepositoryProvider.overrideWithValue(server)],
    );
    addTearDown(container.dispose);
    await container.read(chatProvider('c1').future);
  });

  test('a sent message shows at once, then gets its tick', () async {
    server.hold = Completer();
    final sending = controller().send('On my way');

    expect(chat().last.text, 'On my way');
    expect(chat().last.status, MessageStatus.sending);

    server.hold!.complete();
    await sending;
    expect(chat().last.status, MessageStatus.sent);
    expect(chat().last.isLocal, isFalse);
    expect(chat(), hasLength(2));
  });

  test('without a connection it says so, and tapping sends it again', () async {
    server.offline = true;
    await expectLater(controller().send('Hi'), throwsA(isA<ApiException>()));
    expect(chat().last.status, MessageStatus.failed);

    server.offline = false;
    await controller().retry(chat().last);
    expect(chat().last.status, MessageStatus.sent);
    expect(chat().where((m) => m.text == 'Hi'), hasLength(1));
  });

  test(
    'opening again keeps the chat: only newer messages are fetched',
    () async {
      server.receive('Are you coming?');
      await controller().fetchNewer();
      await controller().fetchNewer(); // nothing new: nothing doubled

      expect(chat().map((m) => m.text), ['Hello', 'Are you coming?']);
      expect(server.loads, 3); // the first load, then twice "only newer"
    },
  );

  test('my message coming back live replaces the waiting copy', () async {
    server.hold = Completer();
    final sending = controller().send('See you');
    // The live connection reports it before the send itself answers.
    await controller().fetchNewer();
    expect(chat().where((m) => m.text == 'See you'), hasLength(1));
    expect(chat().last.isLocal, isFalse);

    server.hold!.complete();
    await sending;
    expect(chat().where((m) => m.text == 'See you'), hasLength(1));
  });
}
