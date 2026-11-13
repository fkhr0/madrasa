import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_direction.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../../../core/l10n/language.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  /// How often an open chat asks for newer messages when the live connection is down.
  static const _checkEvery = Duration(seconds: 5);

  Timer? _check;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    // Opening the chat clears its unread badge; a chat kept in memory
    // shows at once and only asks for what is new.
    Future.microtask(() {
      ref.read(openChatProvider.notifier).state = widget.conversationId;
      ref.read(messageActionsProvider).markRead(widget.conversationId);
      // Ticks, edits and deletions since it was last on screen.
      _chat.refresh().ignore();
    });
    _check = Timer.periodic(_checkEvery, (_) {
      final live = ref.read(realtimeClientProvider)?.isConnected ?? false;
      if (live && _ticks++ % 6 != 0) return;
      _chat.fetchNewer().ignore();
    });
  }

  ChatController get _chat =>
      ref.read(chatProvider(widget.conversationId).notifier);

  Future<void> _retry(MessageModel failed) async {
    try {
      await _chat.retry(failed);
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  void deactivate() {
    // Leaving the chat: its new messages get a banner again.
    final open = ref.read(openChatProvider.notifier);
    if (open.state == widget.conversationId) open.state = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _check?.cancel();
    super.dispose();
  }

  /// Long press on my message: edit (first 15 minutes) or delete.
  Future<void> _actionsFor(MessageModel message) async {
    if (!message.isMine || message.deleted || message.isLocal) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(tr('Edit')),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: Text(
                tr('Delete for everyone'),
                style: const TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'edit') {
        final text = await _askNewText(message.text);
        if (text != null && text != message.text) {
          await _chat.edit(message, text);
        }
      } else {
        final sure = await confirmDelete(
          context,
          title: tr('Delete this message?'),
          message: tr('It is deleted for everyone in this chat.'),
        );
        if (sure) await _chat.delete(message);
      }
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  Future<String?> _askNewText(String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Edit message')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          textDirection: directionOf(current),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: Text(tr('Save')),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _send(String text) async {
    try {
      await _chat.send(text);
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref
        .watch(conversationByIdProvider(widget.conversationId))
        .valueOrNull;
    final messages = ref.watch(chatProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: conversation == null ? null : _ChatTitle(conversation),
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: messages,
              onRetry: () =>
                  ref.invalidate(chatProvider(widget.conversationId)),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: tr('Say hello'),
                    message: tr(
                      'Messages are visible to everyone in this chat.',
                    ),
                  );
                }

                // reverse: true keeps the newest message at the bottom.
                final newestFirst = items.reversed.toList();

                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: newestFirst.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => MessageBubble(
                    // Same message (sending → sent): same bubble, no flicker.
                    key: ValueKey(newestFirst[i].id),
                    message: newestFirst[i],
                    showSenderName: conversation?.isGroup ?? false,
                    onRetry: newestFirst[i].status == MessageStatus.failed
                        ? () => _retry(newestFirst[i])
                        : null,
                    onLongPress: () => _actionsFor(newestFirst[i]),
                  ),
                );
              },
            ),
          ),
          MessageInput(onSend: _send),
        ],
      ),
    );
  }
}

class _ChatTitle extends StatelessWidget {
  final ConversationModel conversation;

  const _ChatTitle(this.conversation);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (conversation.isGroup)
          IconBox(icon: Icons.groups_outlined, color: context.palette.primary)
        else
          UserAvatar(name: conversation.title),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.title,
                style: context.text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(conversation.subtitle, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
