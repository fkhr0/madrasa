import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../logic/trip_rules.dart';
import '../models/bus_route_model.dart';
import '../models/transport_settings_model.dart';
import '../models/trip_model.dart';
import '../providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Administrator: when drivers may start their trips.
/// Changes apply at once and show today's windows for every line.
class TransportSettingsPage extends ConsumerWidget {
  const TransportSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(transportSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Trip rules'))),
      body: AsyncValueView(
        value: settings,
        data: (settings) {
          void save(TransportSettingsModel s) =>
              ref.read(transportActionsProvider).saveSettings(s);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                tr(
                  'Drivers can start a trip only inside its window, only on school days, and only once a day. These rules run on the driver\'s phone and on the server.',
                ),
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Stepper(
                title: tr('Start up to'),
                value: settings.opensBeforeMinutes,
                suffix: tr('min before the first stop'),
                min: 0,
                max: 120,
                onChanged: (v) =>
                    save(settings.copyWith(opensBeforeMinutes: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              _Stepper(
                title: tr('Start no later than'),
                value: settings.closesAfterMinutes,
                suffix: tr('min after the last stop'),
                min: 0,
                max: 180,
                onChanged: (v) =>
                    save(settings.copyWith(closesAfterMinutes: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: settings.testMode
                    ? AppColors.warning.withValues(alpha: 0.12)
                    : null,
                borderColor: settings.testMode ? Colors.transparent : null,
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: settings.testMode,
                  onChanged: (v) => save(settings.copyWith(testMode: v)),
                  title: Text(tr('Test mode')),
                  subtitle: Text(
                    tr(
                      'Drivers may start trips at any time, even on holidays. Turn it off when the school really uses the buses.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: tr('Today\'s windows')),
              _TodayWindows(settings: settings),
            ],
          );
        },
      ),
    );
  }
}

class _TodayWindows extends ConsumerWidget {
  final TransportSettingsModel settings;

  const _TodayWindows({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(busRoutesProvider).valueOrNull ?? [];
    final DateTime now = ref.watch(nowProvider);

    String window(BusRouteModel route, TripDirection direction) {
      final (opens, closes) = tripWindow(route, direction, now, settings);
      return '${DateFormatter.time(opens)}–${DateFormatter.time(closes)}';
    }

    return AppCard(
      child: Column(
        children: [
          for (final route in routes)
            if (route.stops.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Bus {0}', [route.busNumber]),
                        style: context.text.titleSmall,
                      ),
                    ),
                    Text(
                      '☀ ${window(route, TripDirection.toSchool)}   '
                      '☾ ${window(route, TripDirection.toHome)}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String title;
  final int value;
  final String suffix;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.title,
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.bodySmall),
                Text('$value $suffix', style: context.text.titleSmall),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: tr('15 minutes less'),
            onPressed: value - 15 < min ? null : () => onChanged(value - 15),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: tr('15 minutes more'),
            onPressed: value + 15 > max ? null : () => onChanged(value + 15),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
