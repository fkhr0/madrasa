import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../repo/api_message_repository.dart';
import '../repo/message_repository.dart';
import '../repo/mock_message_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => AppConfig.useApi
      ? ApiMessageRepository(watchApi(ref))
      : MockMessageRepository(),
);

/// Every 15 seconds while the live connection is down; while it is up, new
/// messages refresh the list through it, and this only checks every 2 minutes.
final _conversationCheckProvider = StreamProvider<int>((ref) {
  if (!AppConfig.useApi) return const Stream.empty();
  return Stream.periodic(const Duration(seconds: 15), (i) => i).where((i) {
    final live = ref.read(realtimeClientProvider)?.isConnected ?? false;
    return !live || i % 8 == 0;
  });
});

/// New chats and unread badges show up by themselves.
final conversationsProvider = FutureProvider<List<ConversationModel>>((ref) {
  ref.watch(_conversationCheckProvider);
  return ref
      .watch(messageRepositoryProvider)
      .getConversations(ref.watch(currentUserProvider).id);
});

/// Text typed in the search box on the Messages page.
final conversationSearchProvider = StateProvider<String>((ref) => '');

final filteredConversationsProvider = FutureProvider<List<ConversationModel>>((
  ref,
) async {
  final query = ref.watch(conversationSearchProvider).trim().toLowerCase();
  final all = await ref.watch(conversationsProvider.future);

  if (query.isEmpty) return all;

  return all
      .where(
        (c) =>
            c.title.toLowerCase().contains(query) ||
            c.lastMessage.toLowerCase().contains(query),
      )
      .toList();
});

/// Total unread messages, for the badge on the Messages tab.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];

  return conversations.fold(0, (sum, c) => sum + c.unreadCount);
});

final conversationByIdProvider =
    FutureProvider.family<ConversationModel?, String>((ref, id) async {
      final all = await ref.watch(conversationsProvider.future);

      for (final conversation in all) {
        if (conversation.id == id) return conversation;
      }

      return null;
    });

/// The chat on screen now (no banner for its new messages).
final openChatProvider = StateProvider<String?>((ref) => null);

/// One chat's messages, kept in memory like a messaging app: opening the
/// chat again shows them at once, and only newer messages are fetched.
final chatProvider =
    AsyncNotifierProvider.family<ChatController, List<MessageModel>, String>(
      ChatController.new,
    );

class ChatController extends FamilyAsyncNotifier<List<MessageModel>, String> {
  var _nextLocalId = 0;

  MessageRepository get _repository => ref.read(messageRepositoryProvider);

  @override
  Future<List<MessageModel>> build(String conversationId) {
    // Another person signs in on this phone: their chats, not these.
    ref.watch(authProvider.select((user) => user?.id));
    return _repository.getMessages(conversationId);
  }

  /// What arrived since the last message we have (the live connection says
  /// when, and the chat checks now and then in case it was missed).
  Future<void> fetchNewer() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final confirmed = current.where((m) => !m.isLocal);
    final after = confirmed.isEmpty ? null : confirmed.last.sentAt;
    final newer = await _repository.getMessages(arg, after: after);
    if (newer.isNotEmpty) _merge(newer);
  }

  /// The whole chat again, keeping what is still sending: ticks that turned
  /// to ✓✓, edits and deletions (on opening, and when the server says so).
  Future<void> refresh() async {
    if (state.valueOrNull == null) return;
    final fresh = await _repository.getMessages(arg);
    final sending = (state.valueOrNull ?? []).where((m) => m.isLocal);
    state = AsyncData([...fresh, ...sending]);
  }

  Future<void> edit(MessageModel message, String text) async {
    final edited = await _repository.editMessage(message, text);
    _replace(message.id, edited.copyWith(status: message.status));
    ref.invalidate(conversationsProvider);
  }

  Future<void> delete(MessageModel message) async {
    await _repository.deleteMessage(message);
    _replace(message.id, message.copyWith(text: '', deleted: true));
    ref.invalidate(conversationsProvider);
  }

  /// Shows the message at once (a clock), then a tick when the server has
  /// it, or a warning to tap and try again.
  Future<void> send(String text) async {
    final local = MessageModel(
      id: '${MessageModel.localIdPrefix}${_nextLocalId++}',
      conversationId: arg,
      senderName: '',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
      status: MessageStatus.sending,
    );
    state = AsyncData([...?state.valueOrNull, local]);
    await _deliver(local);
  }

  /// A message that failed: send it again.
  Future<void> retry(MessageModel failed) async {
    _replace(failed.id, failed.copyWith(status: MessageStatus.sending));
    await _deliver(failed);
  }

  Future<void> _deliver(MessageModel local) async {
    try {
      final sent = await _repository.sendMessage(arg, local.text);
      final list = [...?state.valueOrNull]
        ..removeWhere((m) => m.id == local.id);
      // The live connection may have brought it already.
      if (!list.any((m) => m.id == sent.id)) list.add(sent);
      state = AsyncData(list);
      ref.invalidate(conversationsProvider); // the preview in the list
    } catch (_) {
      _replace(local.id, local.copyWith(status: MessageStatus.failed));
      rethrow;
    }
  }

  /// Adds messages we don't have yet. My own message coming back from the
  /// server replaces the copy still waiting here.
  void _merge(List<MessageModel> incoming) {
    final list = [...?state.valueOrNull];
    for (final message in incoming) {
      if (list.any((m) => m.id == message.id)) continue;
      final waiting = message.isMine
          ? list.indexWhere(
              (m) =>
                  m.isLocal &&
                  m.status == MessageStatus.sending &&
                  m.text == message.text,
            )
          : -1;
      if (waiting >= 0) {
        list[waiting] = message;
      } else {
        list.add(message);
      }
    }
    // Sending ones stay last, like in any messaging app.
    list.sort((a, b) {
      if (a.isLocal != b.isLocal) return a.isLocal ? 1 : -1;
      return a.sentAt.compareTo(b.sentAt);
    });
    state = AsyncData(list);
  }

  void _replace(String id, MessageModel message) {
    state = AsyncData([
      for (final m in state.valueOrNull ?? <MessageModel>[])
        m.id == id ? message : m,
    ]);
  }
}

/// People this user may start a private chat with.
final contactsProvider = FutureProvider.autoDispose<List<ContactModel>>(
  (ref) => ref.watch(messageRepositoryProvider).getContacts(),
);

final messageActionsProvider = Provider<MessageActions>(MessageActions.new);

/// Sending, reading and starting chats. They throw ApiException with a
/// message to show.
class MessageActions {
  final Ref _ref;

  MessageActions(this._ref);

  MessageRepository get _repository => _ref.read(messageRepositoryProvider);

  Future<void> markRead(String conversationId) async {
    await _repository.markAsRead(conversationId);
    _ref.invalidate(conversationsProvider);
  }

  /// Opens the private chat with [userId]; returns its ID.
  Future<String> startWith(String userId) async {
    final id = await _repository.startConversation(userId);
    _ref.invalidate(conversationsProvider);
    return id;
  }
}
