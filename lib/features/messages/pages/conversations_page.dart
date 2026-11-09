import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/message_provider.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/new_chat_sheet.dart';
import '../../../core/l10n/language.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(filteredConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Messages'))),
      floatingActionButton: FloatingActionButton(
        tooltip: tr('New message'),
        onPressed: () => showNewChatSheet(context),
        child: const Icon(Icons.edit_outlined),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: TextField(
              onChanged: (value) =>
                  ref.read(conversationSearchProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: tr('Search conversations'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: conversations,
              onRetry: () => ref.invalidate(conversationsProvider),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: tr('No conversations found'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    indent: AppSpacing.page + 60,
                    endIndent: AppSpacing.page,
                  ),
                  itemBuilder: (_, i) =>
                      ConversationTile(conversation: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
