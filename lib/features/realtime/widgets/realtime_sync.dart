import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language.dart';
import '../../../core/network/realtime_client.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/text_direction.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/message_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../providers/realtime_provider.dart';

/// Keeps the live connection open while the app's tabs are shown, and reloads
/// exactly what the server says changed.
class RealtimeSync extends ConsumerWidget {
  final Widget child;

  const RealtimeSync({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(realtimeEventsProvider, (_, next) {
      final event = next.valueOrNull;
      if (event == null) return;

      switch (event.type) {
        case 'message.new':
          ref.invalidate(conversationsProvider);
          final id = event['conversationId'];
          if (id == null) break;
          // A chat already in memory gets just the new message; others load
          // when they are opened.
          if (ref.exists(chatProvider(id))) {
            ref.read(chatProvider(id).notifier).fetchNewer().ignore();
          }
          // Someone else wrote, and that chat isn't on screen: a banner.
          final me = ref.read(currentUserProvider).id;
          if (event['senderId'] != me && ref.read(openChatProvider) != id) {
            _showMessageBanner(context, event, id);
          }
        case 'message.changed' || 'messages.seen':
          ref.invalidate(conversationsProvider);
          if (event['conversationId'] case final String id
              when ref.exists(chatProvider(id))) {
            ref.read(chatProvider(id).notifier).refresh().ignore();
          }
        case 'notification.new':
          ref.invalidate(notificationsProvider);
      }
    });

    return child;
  }

  void _showMessageBanner(
    BuildContext context,
    RealtimeEvent event,
    String conversationId,
  ) {
    final preview = event['preview'] ?? '';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['senderName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: directionOf(preview),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: tr('Open'),
            onPressed: () => context.push(AppRoutes.chat(conversationId)),
          ),
        ),
      );
  }
}
