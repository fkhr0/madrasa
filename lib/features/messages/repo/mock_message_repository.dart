import '../data/mock_messages.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'message_repository.dart';

/// Keeps chats in memory so sent messages stay during the session.
class MockMessageRepository implements MessageRepository {
  final List<ConversationModel> _conversations = [
    ...MockMessages.conversations,
    ...MockMessages.teacherConversations,
    ...MockMessages.parentConversations,
    ...MockMessages.adminConversations,
  ];
  final List<MessageModel> _messages = MockMessages.messages;

  /// Chats opened during the session (shown to everyone in mock mode).
  final Set<String> _started = {};

  static const _contacts = [
    ContactModel(
      id: 'TCH-2019-0031',
      name: 'Ahmed Kareem',
      detail: 'Mathematics teacher',
    ),
    ContactModel(
      id: 'TCH-2019-0042',
      name: 'Huda Jaber',
      detail: 'Arabic Language teacher',
    ),
    ContactModel(
      id: 'TCH-2019-0041',
      name: 'Omar Saleh',
      detail: 'Chemistry teacher',
    ),
    ContactModel(
      id: 'ADM-2020-0001',
      name: 'School Office',
      detail: 'School office',
    ),
  ];

  @override
  Future<List<ConversationModel>> getConversations(String userId) async {
    final ids = {...MockMessages.conversationIdsOf(userId), ..._started};

    return _conversations.where((c) => ids.contains(c.id)).toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? after,
  }) async {
    return _messages
        .where(
          (m) =>
              m.conversationId == conversationId &&
              (after == null || m.sentAt.isAfter(after)),
        )
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  @override
  Future<MessageModel> sendMessage(String conversationId, String text) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final message = MessageModel(
      id: 'm${_messages.length + 1}',
      conversationId: conversationId,
      senderName: 'Me',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.sent,
    );
    _messages.add(message);

    _update(
      conversationId,
      (c) => c.copyWith(lastMessage: text, lastMessageAt: message.sentAt),
    );

    return message;
  }

  @override
  Future<MessageModel> editMessage(MessageModel message, String text) async {
    final i = _messages.indexWhere((m) => m.id == message.id);
    _messages[i] = _messages[i].copyWith(text: text, edited: true);
    return _messages[i];
  }

  @override
  Future<void> deleteMessage(MessageModel message) async {
    final i = _messages.indexWhere((m) => m.id == message.id);
    _messages[i] = _messages[i].copyWith(text: '', deleted: true);
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    _update(conversationId, (c) => c.copyWith(unreadCount: 0));
  }

  @override
  Future<List<ContactModel>> getContacts() async => _contacts;

  @override
  Future<String> startConversation(String userId) async {
    final contact = _contacts.firstWhere((c) => c.id == userId);
    final id = 'chat-$userId';
    if (!_conversations.any((c) => c.id == id)) {
      _conversations.add(
        ConversationModel(
          id: id,
          title: contact.name,
          subtitle: contact.detail,
          lastMessage: '',
          lastMessageAt: DateTime.now(),
        ),
      );
    }
    _started.add(id);
    return id;
  }

  void _update(
    String conversationId,
    ConversationModel Function(ConversationModel) change,
  ) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) _conversations[index] = change(_conversations[index]);
  }
}
