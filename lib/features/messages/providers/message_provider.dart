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

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => AppConfig.useApi
      ? ApiMessageRepository(watchApi(ref))
      : MockMessageRepository(),
);

final _conversationCheckProvider = StreamProvider<int>((ref) {
  if (!AppConfig.useApi) return const Stream.empty();
  return Stream.periodic(const Duration(seconds: 15), (i) => i).where((i) {
    final live = ref.read(realtimeClientProvider)?.isConnected ?? false;
    return !live || i % 8 == 0;
  });
});

final conversationsProvider = FutureProvider<List<ConversationModel>>((ref) {
  ref.watch(_conversationCheckProvider);
  return ref
      .watch(messageRepositoryProvider)
      .getConversations(ref.watch(currentUserProvider).id);
});

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

final openChatProvider = StateProvider<String?>((ref) => null);

final chatProvider =
    AsyncNotifierProvider.family<ChatController, List<MessageModel>, String>(
      ChatController.new,
    );

class ChatController extends FamilyAsyncNotifier<List<MessageModel>, String> {
  var _nextLocalId = 0;

  MessageRepository get _repository => ref.read(messageRepositoryProvider);

  @override
  Future<List<MessageModel>> build(String conversationId) {
    ref.watch(authProvider.select((user) => user?.id));
    return _repository.getMessages(conversationId);
  }

  Future<void> fetchNewer() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final confirmed = current.where((m) => !m.isLocal);
    final after = confirmed.isEmpty ? null : confirmed.last.sentAt;
    final newer = await _repository.getMessages(arg, after: after);
    if (newer.isNotEmpty) _merge(newer);
  }

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

  Future<void> retry(MessageModel failed) async {
    _replace(failed.id, failed.copyWith(status: MessageStatus.sending));
    await _deliver(failed);
  }

  Future<void> _deliver(MessageModel local) async {
    try {
      final sent = await _repository.sendMessage(arg, local.text);
      final list = [...?state.valueOrNull]
        ..removeWhere((m) => m.id == local.id);
      if (!list.any((m) => m.id == sent.id)) list.add(sent);
      state = AsyncData(list);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      _replace(local.id, local.copyWith(status: MessageStatus.failed));
      rethrow;
    }
  }

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

final contactsProvider = FutureProvider.autoDispose<List<ContactModel>>(
  (ref) => ref.watch(messageRepositoryProvider).getContacts(),
);

final messageActionsProvider = Provider<MessageActions>(MessageActions.new);

class MessageActions {
  final Ref _ref;

  MessageActions(this._ref);

  MessageRepository get _repository => _ref.read(messageRepositoryProvider);

  Future<void> markRead(String conversationId) async {
    await _repository.markAsRead(conversationId);
    _ref.invalidate(conversationsProvider);
  }

  Future<String> startWith(String userId) async {
    final id = await _repository.startConversation(userId);
    _ref.invalidate(conversationsProvider);
    return id;
  }
}
