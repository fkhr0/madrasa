import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/bus_route_model.dart';
import '../../../core/l10n/language.dart';

/// Bus number, plate, and the people to call (never the viewer themself).
class BusInfoCard extends ConsumerWidget {
  final BusRouteModel route;

  const BusInfoCard({super.key, required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTheDriver = ref.watch(currentUserProvider).id == route.driverId;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          InfoRow(
            icon: Icons.directions_bus_outlined,
            label: tr('Bus'),
            value: tr('No. {0} · {1}', [route.busNumber, route.plateNumber]),
          ),
          InfoRow(
            icon: Icons.route_outlined,
            label: tr('Line'),
            value: route.name,
          ),
          const Divider(),
          if (isTheDriver)
            const SizedBox.shrink()
          else if (route.hasDriver)
            _Person(
              role: tr('Driver'),
              name: route.driverName,
              phone: route.driverPhone,
            )
          else
            InfoRow(
              icon: Icons.person_off_outlined,
              label: tr('Driver'),
              value: tr('Not assigned yet'),
            ),
          if (route.supervisorName.isNotEmpty)
            _Person(
              role: tr('Supervisor'),
              name: route.supervisorName,
              phone: route.supervisorPhone,
            ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  final String role;
  final String name;
  final String phone;

  const _Person({required this.role, required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          UserAvatar(name: name, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.text.titleSmall),
                Text(role, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: tr('Call {0}', [phone]),
            onPressed: () => callPhone(context, phone),
            icon: const Icon(Icons.phone_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}
