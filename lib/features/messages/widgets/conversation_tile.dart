import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/conversation_model.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;

  const ConversationTile({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: () => context.push(AppRoutes.chat(conversation.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (conversation.isGroup)
              IconBox(
                icon: Icons.groups_outlined,
                color: palette.primary,
                size: AppSizes.avatarMd,
              )
            else
              UserAvatar(name: conversation.title, size: AppSizes.avatarMd),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          style: context.text.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormatter.shortStamp(conversation.lastMessageAt),
                        style: context.text.labelSmall?.copyWith(
                          color: hasUnread
                              ? palette.primary
                              : palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: context.text.bodySmall?.copyWith(
                            color: hasUnread ? palette.textPrimary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        _UnreadBadge(count: conversation.unreadCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: context.text.labelSmall?.copyWith(color: palette.onPrimary),
      ),
    );
  }
}
