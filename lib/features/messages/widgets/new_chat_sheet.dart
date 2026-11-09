import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/conversation_model.dart';
import '../providers/message_provider.dart';
import '../../../core/l10n/language.dart';

/// Pick someone to message; opens the chat with them. Only people this
/// user may talk to are listed (teachers of the class, the office...).
Future<void> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NewChatSheet(),
  );
}

class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  String _query = '';

  Future<void> _open(ContactModel contact) async {
    try {
      final id = await ref.read(messageActionsProvider).startWith(contact.id);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(AppRoutes.chat(id));
    } on ApiException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Text(tr('New message'), style: context.text.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: tr('Search people'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AsyncValueView(
              value: contacts,
              onRetry: () => ref.invalidate(contactsProvider),
              data: (all) {
                final shown = all
                    .where(
                      (c) =>
                          _query.isEmpty ||
                          c.name.toLowerCase().contains(_query) ||
                          c.detail.toLowerCase().contains(_query),
                    )
                    .toList();
                if (shown.isEmpty) {
                  return Center(
                    child: Text(
                      tr('Nobody found'),
                      style: context.text.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: UserAvatar(name: shown[i].name, size: 36),
                    title: Text(shown[i].name),
                    subtitle: Text(shown[i].detail),
                    onTap: () => _open(shown[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
