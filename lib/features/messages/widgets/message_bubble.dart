import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/text_direction.dart';
import '../models/message_model.dart';

/// My messages: right, tinted. Others: left, card colour.
/// In groups the sender's name is shown above their messages.
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool showSenderName;

  /// A message that failed to send: tapping it tries again.
  final VoidCallback? onRetry;

  /// Edit or delete (my messages).
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.showSenderName = false,
    this.onRetry,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isMine = message.isMine;

    const radius = Radius.circular(AppRadius.lg);
    const tail = Radius.circular(AppRadius.sm / 2);

    final bubble = Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2,
            AppSpacing.sm + 2,
            AppSpacing.md + 2,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isMine ? palette.primarySoft : palette.card,
            border: isMine ? null : Border.all(color: palette.border),
            // The small "tail" corner points to the sender's side (it
            // flips with the reading direction).
            borderRadius: BorderRadiusDirectional.only(
              topStart: radius,
              topEnd: radius,
              bottomStart: isMine ? radius : tail,
              bottomEnd: isMine ? tail : radius,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSenderName && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName,
                    style: context.text.labelMedium?.copyWith(
                      color: palette.primary,
                    ),
                  ),
                ),
              if (message.deleted)
                Text(
                  tr('This message was deleted'),
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                // Arabic reads right to left, English left to right,
                // whatever the app's language (mixed words stay in order).
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    message.text,
                    textDirection: directionOf(message.text),
                    style: context.text.bodyLarge?.copyWith(
                      color: isMine
                          ? palette.onPrimarySoft
                          : palette.textPrimary,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.edited && !message.deleted) ...[
                    Text(
                      tr('edited'),
                      style: context.text.labelSmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    DateFormatter.time(message.sentAt),
                    style: context.text.labelSmall?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMine && !message.deleted) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      message.status.icon,
                      size: 14,
                      // ✓✓ in the app's colour once seen, like WhatsApp.
                      color: switch (message.status) {
                        MessageStatus.failed => AppColors.danger,
                        MessageStatus.read => palette.primary,
                        _ => palette.textMuted,
                      },
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      tr('Not sent · tap to try again'),
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onRetry,
      onLongPress: onLongPress,
      child: bubble,
    );
  }
}
