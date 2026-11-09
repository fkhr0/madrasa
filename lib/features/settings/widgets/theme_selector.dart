import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/l10n/language.dart';

/// Light / Dark switch. Until the user picks one, the app follows the
/// phone, and the switch shows what the phone is using.
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final shown = switch (mode) {
      ThemeMode.light => ThemeMode.light,
      ThemeMode.dark => ThemeMode.dark,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            tr('APPEARANCE'),
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ),
        AppCard(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(tr('Light')),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(tr('Dark')),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {shown},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).state = selection.first,
            ),
          ),
        ),
      ],
    );
  }
}
