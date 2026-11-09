import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../files/providers/file_provider.dart';
import '../models/resource_model.dart';
import '../../../core/l10n/language.dart';

class ResourceTile extends ConsumerWidget {
  final ResourceModel resource;

  /// Staff: shown at the end to remove it.
  final Widget? trailing;

  const ResourceTile({super.key, required this.resource, this.trailing});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final file = resource.file;
    final url = resource.url;
    if (file != null) return openFile(context, ref, file);
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    context.showMessage(tr('Files open in the server version of the app'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = resource.type;
    final palette = context.palette;

    final details = [
      type.label,
      if (resource.detail != null) resource.detail!,
      DateFormatter.dayMonth(resource.uploadedAt),
    ].join(' · ');

    return AppCard(
      onTap: () => _open(context, ref),
      child: Row(
        children: [
          IconBox(icon: type.icon, color: type.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: resource.subject.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        resource.subject.name,
                        style: context.text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  details,
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          trailing ??
              Icon(
                resource.url != null
                    ? Icons.open_in_new
                    : Icons.download_outlined,
                size: 20,
                color: palette.textMuted,
              ),
        ],
      ),
    );
  }
}
