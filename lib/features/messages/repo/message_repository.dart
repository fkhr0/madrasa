import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract class MessageRepository {
  Future<List<ConversationModel>> getConversations(String userId);

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? after,
  });

  Future<MessageModel> sendMessage(String conversationId, String text);

  Future<MessageModel> editMessage(MessageModel message, String text);

  Future<void> deleteMessage(MessageModel message);

  Future<void> markAsRead(String conversationId);

  Future<List<ContactModel>> getContacts();

  Future<String> startConversation(String userId);
}
