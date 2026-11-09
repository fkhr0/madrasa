import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/utils/context_extensions.dart';

/// A thin bar above the page while the server can't be reached and the
/// screens show what was saved on this phone (ApiClient.offline).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.useApi) return const SizedBox.shrink();
    final offline = ref.watch(apiClientProvider).offline;

    return ValueListenableBuilder<bool>(
      valueListenable: offline,
      builder: (context, isOffline, _) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: !isOffline
            ? const SizedBox(width: double.infinity)
            : Material(
                color: context.palette.cardMuted,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 16,
                          color: context.palette.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('No connection. Showing what was saved.'),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
