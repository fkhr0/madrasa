import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../transport/providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Driver tells everyone on the route the bus is late, and why.
Future<void> showDelaySheet(BuildContext context, String routeId) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => _DelaySheet(routeId: routeId),
  );
}

class _DelaySheet extends ConsumerStatefulWidget {
  final String routeId;

  const _DelaySheet({required this.routeId});

  @override
  ConsumerState<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends ConsumerState<_DelaySheet> {
  static const _minutes = [5, 10, 20, 30];
  // Sent in English: the server tells each family in their app's language.
  static const _reasons = [
    'Traffic',
    'Checkpoint',
    'Road closed',
    'Waiting for a student',
    'Bus problem',
  ];

  int _delay = 10;
  String _reason = _reasons.first;

  Future<void> _send() async {
    await ref
        .read(transportActionsProvider)
        .reportDelay(widget.routeId, _delay, _reason);
    if (!mounted) return;

    Navigator.of(context).pop();
    context.showMessage(tr('Students and parents were told'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Report a delay'), style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('About how late?'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in _minutes)
                  ChoiceChip(
                    label: Text(tr('{0} min', [m])),
                    selected: _delay == m,
                    onSelected: (_) => setState(() => _delay = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tr('Why?'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in _reasons)
                  ChoiceChip(
                    label: Text(tr(r)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: _send, child: Text(tr('Tell everyone'))),
          ],
        ),
      ),
    );
  }
}
