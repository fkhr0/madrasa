import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../files/providers/file_provider.dart';
import '../models/attachment_model.dart';

/// A file row. Shows a remove button when [onRemove] is given
/// (files about to be handed in or attached); otherwise a tap opens it.
class AttachmentTile extends ConsumerWidget {
  final AttachmentModel attachment;
  final VoidCallback? onRemove;

  const AttachmentTile({super.key, required this.attachment, this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Material(
      color: palette.cardMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onRemove == null
            ? () => openFile(context, ref, attachment)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(attachment.type.icon, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      style: context.text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(attachment.size, style: context.text.bodySmall),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                )
              else
                Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: palette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
