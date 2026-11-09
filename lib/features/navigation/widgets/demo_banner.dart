import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../auth/providers/auth_provider.dart';

/// "Demo school": shown while someone looks around with "Try the app", so
/// nobody takes the sample data for a real school.
class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(authProvider.select((u) => u?.isDemo ?? false));
    if (!isDemo) return const SizedBox.shrink();

    return Material(
      color: AppColors.info.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Demo school · it goes back to how it was every night'),
                  style: context.text.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
