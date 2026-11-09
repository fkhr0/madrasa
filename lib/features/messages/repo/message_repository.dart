import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// MockMessageRepository or ApiMessageRepository. New messages arrive
/// through the live connection; ChatController keeps each chat in memory.
/// Failures throw ApiException with a message to show.
abstract class MessageRepository {
  /// Conversations of [userId], newest first.
  Future<List<ConversationModel>> getConversations(String userId);

  /// Oldest message first. Reading marks the chat as read. With [after],
  /// only the messages sent after that moment (what is new since).
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? after,
  });

  Future<MessageModel> sendMessage(String conversationId, String text);

  /// The writer, within MessageModel.editableFor of sending.
  Future<MessageModel> editMessage(MessageModel message, String text);

  /// The writer: deleted for everyone.
  Future<void> deleteMessage(MessageModel message);

  Future<void> markAsRead(String conversationId);

  /// People this user may start a private chat with.
  Future<List<ContactModel>> getContacts();

  /// Opens the private chat with [userId] (always the same one); its ID.
  Future<String> startConversation(String userId);
}
