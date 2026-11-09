import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../logic/trip_text.dart';
import '../providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Small bus card on the student / parent home page.
/// Appears only around trip time, so it never clutters the screen.
class BusMiniCard extends ConsumerWidget {
  const BusMiniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(myTransportProvider).valueOrNull;
    if (transport == null) return const SizedBox.shrink();

    final trip = ref.watch(tripProvider(transport.route.id)).valueOrNull;
    final now = ref.watch(nowProvider);
    if (trip == null || !isTripRelevantNow(trip, now)) {
      return const SizedBox.shrink();
    }

    final text = describeTrip(trip, now, myStopId: transport.stopId);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => context.push(AppRoutes.bus),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconBox(
              icon: Icons.directions_bus,
              color: context.palette.primary,
              size: 38,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Bus {0} · {1}', [
                      transport.route.busNumber,
                      text.title,
                    ]),
                    style: context.text.titleSmall,
                  ),
                  Text(
                    text.detail,
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.palette.textMuted),
          ],
        ),
      ),
    );
  }
}
