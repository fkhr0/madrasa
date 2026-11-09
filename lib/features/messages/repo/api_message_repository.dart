import '../../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'message_repository.dart';

/// Messages on the school API (server/src/features/messages).
class ApiMessageRepository implements MessageRepository {
  final ApiClient _api;

  const ApiMessageRepository(this._api);

  @override
  Future<List<ConversationModel>> getConversations(String userId) async => [
    for (final json in await _api.get('/messages/conversations') as List)
      ConversationModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? after,
  }) async => [
    for (final json
        in await _api.get(
              '/messages/conversations/$conversationId/messages'
              '${after == null ? '' : '?after=${Uri.encodeQueryComponent(after.toUtc().toIso8601String())}'}',
            )
            as List)
      MessageModel.fromJson(
        json as Map<String, dynamic>,
        conversationId: conversationId,
      ),
  ];

  @override
  Future<MessageModel> sendMessage(String conversationId, String text) async =>
      MessageModel.fromJson(
        await _api.post('/messages/conversations/$conversationId/messages', {
              'text': text,
            })
            as Map<String, dynamic>,
        conversationId: conversationId,
      );

  @override
  Future<MessageModel> editMessage(
    MessageModel message,
    String text,
  ) async => MessageModel.fromJson(
    await _api.patch(
          '/messages/conversations/${message.conversationId}/messages/${message.id}',
          {'text': text},
        )
        as Map<String, dynamic>,
    conversationId: message.conversationId,
  );

  @override
  Future<void> deleteMessage(MessageModel message) => _api.delete(
    '/messages/conversations/${message.conversationId}/messages/${message.id}',
  );

  @override
  Future<void> markAsRead(String conversationId) =>
      _api.post('/messages/conversations/$conversationId/read');

  @override
  Future<List<ContactModel>> getContacts() async => [
    for (final json in await _api.get('/messages/contacts') as List)
      ContactModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<String> startConversation(String userId) async {
    final json = await _api.post('/messages/conversations', {'userId': userId});
    return (json as Map)['id'] as String;
  }
}
